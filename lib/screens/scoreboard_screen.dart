import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/score_service.dart';
import '../theme/funky_theme.dart';

class ScoreboardScreen extends StatelessWidget {
  const ScoreboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scoreService = ScoreService();

    return ListenableBuilder(
      listenable: scoreService,
      builder: (context, _) {
        final players = scoreService.rankedPlayers;

        return Scaffold(
          body: FunkyBackground(
            accent: FunkyColors.amber,
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: FunkyColors.card,
                              border: Border.all(
                                color: FunkyColors.amber.withValues(alpha: 0.5),
                                width: 1.3,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'لوحة الشرف 🏆',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color:
                                      FunkyColors.amber.withValues(alpha: 0.7),
                                  blurRadius: 14,
                                ),
                              ],
                            ).copyWith(
                                fontFamilyFallback: const ['Noto Color Emoji']),
                          ),
                        ),
                        if (players.isNotEmpty)
                          GestureDetector(
                            onTap: () =>
                                _showClearConfirm(context, scoreService),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: FunkyColors.card,
                                border: Border.all(
                                  color:
                                      FunkyColors.coral.withValues(alpha: 0.6),
                                  width: 1.3,
                                ),
                              ),
                              child: const Icon(
                                Icons.delete_sweep_rounded,
                                color: FunkyColors.coral,
                                size: 20,
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 42),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: players.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: players.length,
                            itemBuilder: (context, index) =>
                                _buildPlayerCard(players[index], index),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😶', style: TextStyle(fontSize: 80))
                .animate()
                .shake(),
            const SizedBox(height: 20),
            Text(
              'مفيش حد بيلعب لسه!',
              style: GoogleFonts.cairo(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'ابدأ أي لعبة واختار أسماء الشلة عشان تظهر هنا.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(color: Colors.white60),
            ),
            const SizedBox(height: 30),
            FunkyButton(
              label: 'رجوع',
              accent: FunkyColors.amber,
              icon: Icons.arrow_back_rounded,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard(PlayerScore player, int index) {
    final isFirst = index == 0;
    final accent =
        FunkyColors.accents[index % FunkyColors.accents.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: FunkyColors.card,
        borderRadius: BorderRadius.circular(20),
        gradient: isFirst
            ? LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  FunkyColors.amber.withValues(alpha: 0.4),
                  FunkyColors.card,
                ],
              )
            : null,
        border: Border.all(
          color: isFirst
              ? FunkyColors.amber
              : accent.withValues(alpha: 0.35),
          width: isFirst ? 2 : 1,
        ),
        boxShadow: isFirst
            ? [
                BoxShadow(
                  color: FunkyColors.amber.withValues(alpha: 0.4),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: FunkyDecor.accentGradient(
                    isFirst ? FunkyColors.amber : accent),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${player.score}',
                  style: GoogleFonts.cairo(
                    color:
                        isFirst ? FunkyColors.amber : Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'نقطة',
                  style: GoogleFonts.cairo(
                      color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
            if (isFirst) ...[
              const SizedBox(width: 10),
              const Text(
                '👑',
                style: TextStyle(fontSize: 24),
              ).animate(onPlay: (c) => c.repeat()).rotate(duration: 2.seconds),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.2, end: 0);
  }

  void _showClearConfirm(BuildContext context, ScoreService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FunkyColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'إنهاء الجلسة؟',
          style: GoogleFonts.cairo(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ده هيفتح السهم وهيخليك تبدأ من جديد بالأسماء.',
          style: GoogleFonts.cairo(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              service.clearSession();
              Navigator.pop(ctx);
            },
            child: const Text(
              'إنهاء',
              style: TextStyle(color: FunkyColors.coral),
            ),
          ),
        ],
      ),
    );
  }
}

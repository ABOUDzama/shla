import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/score_service.dart';
import '../theme/flat_theme.dart';

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
          backgroundColor: FlatColors.bg,
          body: SafeArea(
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
                            color: Colors.white,
                            border: Border.all(
                              color: FlatColors.border,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: FlatColors.ink,
                            size: 18,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'لوحة الشرف 🏆',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: flatCairo(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: FlatColors.ink,
                          ),
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
                              color: Colors.white,
                              border: Border.all(
                                color: FlatColors.border,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_sweep_rounded,
                              color: FlatColors.playerRed,
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
              style: flatCairo(
                fontSize: 24,
                color: FlatColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'ابدأ أي لعبة واختار أسماء الشلة عشان تظهر هنا.',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: flatCairo(
                color: FlatColors.ink.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                decoration:
                    FlatDecor.button(FlatColors.tilePastels[4]),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      color:
                          FlatDecor.textOn(FlatColors.tilePastels[4]),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'رجوع',
                      style: flatCairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: FlatDecor.textOn(
                            FlatColors.tilePastels[4]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard(PlayerScore player, int index) {
    final isFirst = index == 0;
    final accent = FlatColors
        .tilePastels[index % FlatColors.tilePastels.length];
    final amber = FlatColors.tilePastels[4];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFirst ? amber : FlatColors.border,
          width: 2,
        ),
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
                color: isFirst ? amber : accent,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: flatCairo(
                    fontWeight: FontWeight.w900,
                    color:
                        FlatDecor.textOn(isFirst ? amber : accent),
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
                style: flatCairo(
                  color: FlatColors.ink,
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
                  style: flatCairo(
                    color: isFirst ? amber : FlatColors.ink,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'نقطة',
                  style: flatCairo(
                    color: FlatColors.ink.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'إنهاء الجلسة؟',
          style: flatCairo(
              color: FlatColors.ink, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ده هيفتح السهم وهيخليك تبدأ من جديد بالأسماء.',
          textDirection: TextDirection.rtl,
          style: flatCairo(
              color: FlatColors.ink.withValues(alpha: 0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: flatCairo(color: FlatColors.ink),
            ),
          ),
          TextButton(
            onPressed: () {
              service.clearSession();
              Navigator.pop(ctx);
            },
            child: Text(
              'إنهاء',
              style: flatCairo(
                  color: FlatColors.playerRed,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

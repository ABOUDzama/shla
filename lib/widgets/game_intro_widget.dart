import 'package:flutter/material.dart';
import '../theme/funky_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class GameIntroWidget extends StatelessWidget {
  final String title;
  final String description;
  final String icon;
  final VoidCallback onStart;
  final Color? backgroundColor;

  const GameIntroWidget({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onStart,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.rotate(
              angle: 0.08,
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: FunkyDecor.accentGradient(
                      backgroundColor ?? FunkyColors.magenta),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (backgroundColor ?? FunkyColors.magenta)
                          .withValues(alpha: 0.6),
                      blurRadius: 42,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 72),
                ),
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: (backgroundColor ?? FunkyColors.magenta)
                        .withValues(alpha: 0.9),
                    blurRadius: 18,
                  ),
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: FunkyColors.bgDeep.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (backgroundColor ?? FunkyColors.magenta)
                      .withValues(alpha: 0.5),
                  width: 1.4,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: FunkyDecor.pill(
                        backgroundColor ?? FunkyColors.magenta),
                    child: Text(
                      'إزاي تلعب؟',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: GoogleFonts.cairo(
                      fontSize: 17,
                      height: 1.55,
                      color: Colors.white.withValues(alpha: 0.88),
                    ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 400.ms),
                ],
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: FunkyButton(
                label: 'ابدأ اللعبة 🚀',
                onPressed: onStart,
                accent: backgroundColor ?? FunkyColors.magenta,
                icon: Icons.play_arrow_rounded,
                fontSize: 23,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.04, 1.04),
                  duration: 1.seconds,
                  curve: Curves.easeInOut,
                ),
          ],
        ),
      ),
    );
  }
}

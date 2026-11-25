import 'package:flutter/material.dart';
import '../theme/funky_theme.dart';
import 'dart:ui';
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
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: FunkyDecor.accentGradient(
                    backgroundColor ?? FunkyColors.magenta),
                boxShadow: [
                  BoxShadow(
                    color: (backgroundColor ?? FunkyColors.magenta)
                        .withValues(alpha: 0.55),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                icon,
                style: const TextStyle(fontSize: 72),
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: FunkyDecor.glowCard(
                    backgroundColor ?? FunkyColors.magenta,
                    radius: 30,
                  ),
                  child: Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 16),
                      Text(
                        description,
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          height: 1.5,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 400.ms),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            FunkyButton(
                  label: 'ابدأ اللعبة 🚀',
                  onPressed: onStart,
                  accent: backgroundColor ?? FunkyColors.magenta,
                  icon: Icons.play_arrow_rounded,
                  fontSize: 24,
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: 1.seconds,
                  curve: Curves.easeInOut,
                ),
          ],
        ),
      ),
    );
  }
}

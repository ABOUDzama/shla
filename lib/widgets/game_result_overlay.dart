import 'package:flutter/material.dart';
import '../theme/funky_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Full-screen win/lose celebration overlay shown over online games.
class GameResultOverlay extends StatelessWidget {
  final bool isWin;
  final String title;
  final String subtitle;
  final VoidCallback onDismiss;

  const GameResultOverlay({
    super.key,
    required this.isWin,
    required this.title,
    required this.subtitle,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isWin ? FunkyColors.amber : FunkyColors.sky;
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.75),
        child: InkWell(
          onTap: onDismiss,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isWin ? '🏆' : '💪', style: const TextStyle(fontSize: 90))
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.12, 1.12),
                        duration: 700.ms,
                      )
                      .then()
                      .shake(duration: 500.ms, hz: 2),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: accent,

                    ),
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.3),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 17,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                  const SizedBox(height: 36),
                  ElevatedButton.icon(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      'تمام',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isWin ? FunkyColors.magenta : FunkyColors.cardLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.8, 0.8)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

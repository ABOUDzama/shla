import 'package:flutter/material.dart';
import '../theme/flat_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Shared game intro in the approved flat home language (user-approved
/// X/O trial 2026-11-25): cream card, pastel icon tile, ink type, one
/// solid cartoon button. No gradients, no glow.
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
    final accent = backgroundColor ?? FlatColors.tilePastels[3];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: FlatDecor.card(radius: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: FlatDecor.tile(accent, radius: 26),
                child: Center(
                  child: Text(
                    icon,
                    style: const TextStyle(
                      fontSize: 48,
                      fontFamilyFallback: ['Noto Color Emoji'],
                    ),
                  ),
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: FlatDecor.title(size: 26)).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: FlatDecor.tag(),
                child: Text('إزاي تلعب؟', style: FlatDecor.title(size: 13)),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: FlatDecor.body(size: 16).copyWith(
                  height: 1.55,
                  color: FlatColors.ink.withValues(alpha: 0.75),
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: onStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration:
                        FlatDecor.button(FlatColors.tilePastels[3], radius: 18),
                    child: Center(
                      child: Text(
                        'ابدأ اللعبة 🚀',
                        style: FlatDecor.title(size: 19, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/flat_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Shared game intro in the flat home language: pastel icon tile, ink type,
/// info chips (players, bots, one phone) and one solid start button.
/// Plain content widget: callers embed it inside a scaffold
/// (OfflineGameScaffold) which supplies the back chrome.
class GameIntroWidget extends StatelessWidget {
  final String title;
  final String description;
  final String icon;
  final VoidCallback onStart;
  final Color? backgroundColor;

  /// Optional players chip, e.g. '١-٤ لاعبين'.
  final String? playersLabel;

  /// Shows a bots chip when the game can fill seats with bots.
  final bool showBotsChip;

  const GameIntroWidget({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onStart,
    this.backgroundColor,
    this.playersLabel,
    this.showBotsChip = false,
  });

  Widget _chip(String emoji, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlatColors.border, width: 2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji,
            style: const TextStyle(
                fontSize: 13, fontFamilyFallback: ['Noto Color Emoji'])),
        const SizedBox(width: 6),
        Text(label,
            textDirection: TextDirection.rtl,
            style: FlatDecor.body(size: 13)
                .copyWith(fontWeight: FontWeight.w800)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = backgroundColor ?? FlatColors.tilePastels[3];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: FlatDecor.tile(accent, radius: 28),
              child: Center(
                child: Text(
                  icon,
                  style: const TextStyle(
                    fontSize: 56,
                    fontFamilyFallback: ['Noto Color Emoji'],
                  ),
                ),
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: FlatDecor.title(size: 28)).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (playersLabel != null) _chip('👥', playersLabel!),
                if (showBotsChip) _chip('🤖', 'بوتات تكمّل'),
                _chip('📱', 'موبايل واحد'),
              ],
            ).animate().fadeIn(delay: 220.ms),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: FlatDecor.card(radius: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: FlatDecor.tag(),
                      child: Text('إزاي تلعب؟',
                          style: FlatDecor.title(size: 13),
                          textDirection: TextDirection.rtl),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: FlatDecor.body(size: 15).copyWith(
                      height: 1.6,
                      color: FlatColors.ink.withValues(alpha: 0.75),
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: onStart,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration:
                      FlatDecor.button(FlatColors.ink, radius: 18),
                  child: Center(
                    child: Text(
                      'ابدأ اللعبة 🚀',
                      textDirection: TextDirection.rtl,
                      style: FlatDecor.title(
                              size: 19,
                              color: FlatDecor.textOn(FlatColors.ink))
                          .copyWith(
                              fontFamilyFallback: const ['Noto Color Emoji']),
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }
}

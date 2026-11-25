import 'package:flutter/material.dart';
import '../screens/settings_screen.dart';
import '../theme/funky_theme.dart';
import '../services/settings_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OfflineGameScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Color backgroundColor;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final VoidCallback? onAiRefresh;
  final bool showAi;

  const OfflineGameScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.backgroundColor,
    this.actions,
    this.floatingActionButton,
    this.onAiRefresh,
    this.showAi = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // Floating bubble header: a rounded accent-edged bar that hovers
        // over the background instead of the old full-width gradient strip.
        flexibleSpace: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  backgroundColor.withValues(alpha: 0.80),
                  FunkyColors.card.withValues(alpha: 0.92),
                ],
              ),
              border: Border.all(
                color: backgroundColor.withValues(alpha: 0.95),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w900,
            fontSize: 19,
            color: Colors.white,
            shadows: [
              Shadow(
                color: backgroundColor.withValues(alpha: 0.9),
                blurRadius: 10,
              ),
            ],
          ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (SettingsService.isAiEnabled && showAi)
            _HeaderIconButton(
                  icon: Icons.auto_awesome,
                  accent: backgroundColor,
                  onTap: onAiRefresh ?? () {},
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .shimmer(duration: 3.seconds, color: Colors.white30)
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                  duration: 2.seconds,
                ),
          ...?actions,
          _HeaderIconButton(
            icon: Icons.settings_rounded,
            accent: backgroundColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: FunkyBackground(
        accent: backgroundColor,
        child: SafeArea(child: body),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Small filled-circle icon button for the bubble header; the dark filled
/// chip keeps the icon readable on any accent color (contrast fix).
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: FunkyColors.bgDeep.withValues(alpha: 0.75),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

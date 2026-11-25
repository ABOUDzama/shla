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
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                FunkyColors.bgDeep.withValues(alpha: 0.92),
                backgroundColor.withValues(alpha: 0.85),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: backgroundColor.withValues(alpha: 0.8),
                width: 2,
              ),
            ),
          ),
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w900,
            fontSize: 18, // Reduced from 22

            color: Colors.white,
          ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (SettingsService.isAiEnabled && showAi)
            IconButton(
                  icon: const Icon(
                    Icons.auto_awesome,
                    color: Colors.blueAccent,
                  ),
                  onPressed: onAiRefresh ?? () {},
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .shimmer(duration: 3.seconds, color: Colors.white30)
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                  duration: 2.seconds,
                ),
          ...?actions,
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
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

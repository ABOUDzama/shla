import 'package:flutter/material.dart';
import '../screens/settings_screen.dart';
import '../theme/flat_theme.dart';
import '../services/settings_service.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared game scaffold in the approved flat home language (user-approved
/// X/O trial 2026-11-25): cream background, white round chrome buttons,
/// ink Cairo title. No neon strips, no gradients, no glow.
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

  static Widget chromeButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: FlatColors.border, width: 2),
        ),
        child: Icon(icon, size: 20, color: FlatColors.ink),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlatColors.bg,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  chromeButton(
                    icon: Icons.settings_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SettingsScreen()),
                      );
                    },
                  ),
                  if (SettingsService.isAiEnabled && showAi) ...[
                    const SizedBox(width: 8),
                    chromeButton(
                      icon: Icons.auto_awesome,
                      onTap: onAiRefresh ?? () {},
                    ),
                  ],
                  Expanded(
                    child: Center(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: FlatColors.ink,
                        ).copyWith(
                            fontFamilyFallback: const ['Noto Color Emoji']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  ...?actions,
                  chromeButton(
                    icon: Icons.home_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

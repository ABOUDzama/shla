import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Funky party design system for شِلَّة.
/// Vivid, loud, but coherent: one deep space-purple base, a fixed set of
/// saturated accents, and shared gradient/glow building blocks so every
/// screen and game interior feels part of the same party.
class FunkyColors {
  FunkyColors._();

  // Base: deep space purple (dark enough to keep text readable).
  static const Color bgDeep = Color(0xFF160A2E);
  static const Color bgMid = Color(0xFF2A1454);
  static const Color card = Color(0xFF2D1B4E);
  static const Color cardLight = Color(0xFF3D2666);

  // Vivid accents.
  static const Color magenta = Color(0xFFFF2D92);
  static const Color violet = Color(0xFF8B5CFF);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color lime = Color(0xFFB6FF3B);
  static const Color amber = Color(0xFFFFC233);
  static const Color coral = Color(0xFFFF6B57);
  static const Color pink = Color(0xFFFF5CD0);
  static const Color mint = Color(0xFF3DFFC0);
  static const Color orange = Color(0xFFFF8A00);
  static const Color sky = Color(0xFF4DA6FF);

  static const List<Color> accents = [
    magenta,
    violet,
    cyan,
    lime,
    amber,
    coral,
    pink,
    mint,
    orange,
    sky,
  ];

  /// The app's signature gradient (buttons, highlights).
  static const LinearGradient partyGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [magenta, violet, cyan],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgMid, bgDeep],
  );
}

class FunkyText {
  FunkyText._();

  static TextStyle headline({double size = 26, Color color = Colors.white}) =>
      GoogleFonts.cairo(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: 0.5,
        height: 1.2,
      );

  static TextStyle title({double size = 18, Color color = Colors.white}) =>
      GoogleFonts.cairo(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.25,
      );

  static TextStyle body({double size = 15, Color color = Colors.white}) =>
      GoogleFonts.cairo(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.5,
      );
}

class FunkyDecor {
  FunkyDecor._();

  /// A glowing rounded card lifted off the background with an accent tint.
  static BoxDecoration glowCard(Color accent,
      {double radius = 24, double alpha = 0.16}) {
    return BoxDecoration(
      color: FunkyColors.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent.withValues(alpha: 0.65), width: 1.6),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.35),
          blurRadius: 24,
          spreadRadius: -4,
          offset: const Offset(0, 10),
        ),
      ],
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          accent.withValues(alpha: alpha),
          FunkyColors.card,
        ],
      ),
    );
  }

  /// A small vivid pill chip (badges, tags, timers).
  static BoxDecoration pill(Color accent) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      gradient: accentGradient(accent),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.4),
          blurRadius: 12,
          spreadRadius: -3,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// A two-stop vivid gradient derived from one accent.
  static LinearGradient accentGradient(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    final shifted = hsl
        .withHue((hsl.hue + 45) % 360)
        .withSaturation((hsl.saturation * 0.95).clamp(0.0, 1.0))
        .toColor();
    return LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [accent, shifted],
    );
  }
}

/// Full-screen funky background: deep purple gradient with two soft
/// accent glows. Used by scaffolds and screens behind the content.
class FunkyBackground extends StatelessWidget {
  final Color accent;
  final Widget? child;

  const FunkyBackground({super.key, this.accent = FunkyColors.violet, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: FunkyColors.backgroundGradient),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _GlowBlob(color: accent, size: 260),
          ),
          Positioned(
            bottom: -100,
            left: -70,
            child: _GlowBlob(
              color: FunkyDecor.accentGradient(accent).colors.last,
              size: 300,
            ),
          ),
          if (child != null) Positioned.fill(child: child!),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.35),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chunky gradient pill button used for primary actions across games.
class FunkyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final IconData? icon;
  final double fontSize;

  const FunkyButton({
    super.key,
    required this.label,
    this.onPressed,
    this.accent = FunkyColors.magenta,
    this.icon,
    this.fontSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = FunkyDecor.accentGradient(accent);
    return Opacity(
      opacity: onPressed == null ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: fontSize + 4),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: FunkyText.headline(size: fontSize),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

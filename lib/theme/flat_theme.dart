import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Flat/cartoon design direction (PREVIEW, not yet wired app-wide).
/// Grounded in observed App Store screenshots:
/// - WePlay home: light cream bg, flat pastel rounded game tiles with a
///   cartoon character + plain title, tiny "New"/"Popular" tags.
/// - WePlay "Who's the Imposter": flat info card, circular avatars,
///   narrator chat feed, one solid action button.
/// - Heads Up!: flat solid color moments, giant type, no gradients.
/// Applied so far only to the Mafia deal screen (direction preview under
/// user review). On approval these tokens promote the whole app.
class FlatColors {
  static const Color bg = Color(0xFFFFF6E9); // warm cream
  static const Color ink = Color(0xFF2B2140); // near-black violet
  static const Color border = Color(0xFFEFE3D0); // cream border
  static const Color tileWhite = Color(0xFFFFFFFF);

  // Flat pastel tile colors for game cards (WePlay-style rotation).
  static const List<Color> tilePastels = [
    Color(0xFF9B7EDE), // violet
    Color(0xFF4D8DFF), // sky
    Color(0xFF35C99E), // mint
    Color(0xFFFF8A5C), // coral
    Color(0xFFFFC233), // amber
    Color(0xFFFF6FA5), // pink
  ];

  /// Darker mint for success text on light backgrounds (5.4:1 on white;
  /// the pastel mint itself is only 2.1:1).
  static const Color mintDark = Color(0xFF17795A);

  // Role/phase solids.
  static const Color mafia = Color(0xFFFF5A5A);
  static const Color doctor = Color(0xFF35C99E);
  static const Color detective = Color(0xFF4D8DFF);
  static const Color villager = Color(0xFF9B7EDE);
  static const Color night = Color(0xFF3B3561);
  static const Color day = Color(0xFFFFB84D);
}

class FlatDecor {
  /// Flat white card: thin cream border, no glow, no gradient.
  static BoxDecoration card({double radius = 24}) => BoxDecoration(
        color: FlatColors.tileWhite,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: FlatColors.border, width: 2),
      );

  /// Flat solid tile in a pastel role/game color.
  static BoxDecoration tile(Color color, {double radius = 24}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      );

  /// Cartoon-flat solid button: solid fill + darker bottom edge.
  static BoxDecoration button(Color color, {double radius = 16}) {
    final hsl = HSLColor.fromColor(color);
    final dark =
        hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border(bottom: BorderSide(color: dark, width: 5)),
    );
  }

  /// Small flat tag ("جديد", progress): white fill, cream border.
  static BoxDecoration tag() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlatColors.border, width: 2),
      );

  /// Readable text color on a solid fill: whichever of ink/white has the
  /// higher WCAG contrast against the fill. On every flat pastel ink wins
  /// (worst case 4.6:1 on violet), so small button labels always pass 4.5:1;
  /// white only appears on genuinely dark fills (e.g. ink itself).
  static Color textOn(Color bg) {
    double cr(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    return cr(FlatColors.ink, bg) >= cr(Colors.white, bg)
        ? FlatColors.ink
        : Colors.white;
  }

  static TextStyle title({double size = 22, Color color = FlatColors.ink}) =>
      GoogleFonts.cairo(
              fontSize: size, fontWeight: FontWeight.w900, color: color)
          .copyWith(fontFamilyFallback: const ['Noto Color Emoji']);

  static TextStyle body({double size = 14, Color color = FlatColors.ink}) =>
      GoogleFonts.cairo(fontSize: size, color: color)
          .copyWith(fontFamilyFallback: const ['Noto Color Emoji']);
}

/// Emoji fallback for GoogleFonts.cairo text with inline emoji (matches
/// OfflineGameScaffold title; keeps harness goldens truthful).
const List<String> kEmojiFontFallback = ['Noto Color Emoji'];

/// Cairo text style with the emoji fallback baked in, so inline emoji render
/// in tests and on devices without per-call boilerplate.
TextStyle flatCairo({
  TextStyle? textStyle,
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? wordSpacing,
  TextBaseline? textBaseline,
  double? height,
  Locale? locale,
  PaintingStyle? paintStyle,
  List<Shadow>? shadows,
  List<FontFeature>? fontFeatures,
  TextDecoration? decoration,
  Color? decorationColor,
  TextDecorationStyle? decorationStyle,
  double? decorationThickness,
}) =>
    GoogleFonts.cairo(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    ).copyWith(fontFamilyFallback: kEmojiFontFallback);

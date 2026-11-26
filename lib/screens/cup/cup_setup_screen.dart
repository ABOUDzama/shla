import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/game_model.dart';
import '../../services/cup_service.dart';
import '../../services/game_registry.dart';
import '../../theme/flat_theme.dart';
import '../arcade_section_screen.dart';
import 'cup_screen.dart';

/// كأس الشلة setup: pick the cup length and which ١٢٣٤ games it tours.
/// Players and bots are chosen inside each game as usual; the cup only
/// tracks who wins each round.
class CupSetupScreen extends StatefulWidget {
  const CupSetupScreen({super.key});

  @override
  State<CupSetupScreen> createState() => _CupSetupScreenState();
}

class _CupSetupScreenState extends State<CupSetupScreen> {
  static const _emojiFallback = ['Noto Color Emoji'];

  int _rounds = 3;
  bool _random = true;
  final Set<String> _picked = {};

  List<GameModel> get _arcade =>
      GameRegistry.games.where((g) => g.arcade1234).toList();

  List<String> _gamesForCup() {
    if (_random) {
      final titles = _arcade.map((g) => g.title).toList()..shuffle();
      return titles.take(_rounds).toList();
    }
    return _picked.toList();
  }

  bool get _canStart => _random || _picked.length == _rounds;

  Future<void> _start() async {
    final games = _gamesForCup();
    if (games.length != _rounds) return;
    await CupService.instance.start(rounds: _rounds, games: games);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CupScreen()),
    );
  }

  TextStyle _t(double size,
          {FontWeight w = FontWeight.w800, Color? c, double? h}) =>
      GoogleFonts.cairo(
        fontSize: size,
        fontWeight: w,
        color: c ?? FlatColors.ink,
        height: h,
      ).copyWith(fontFamilyFallback: _emojiFallback);

  @override
  Widget build(BuildContext context) {
    final arcade = _arcade;
    return Scaffold(
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: FlatColors.ink),
                ),
                const Spacer(),
              ],
            ),
            Center(
                child: Text('كأس الشلة 🏆', style: _t(28, w: FontWeight.w900))),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'جولات من ألعاب ١٢٣٤، وكل فوز بنقطة.\nأكتر واحد يجمع نقاط ياخد الكأس!',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: _t(13, w: FontWeight.w700, h: 1.5)
                    .copyWith(color: FlatColors.ink.withValues(alpha: 0.75)),
              ),
            ),
            const SizedBox(height: 20),
            Text('عدد الجولات', style: _t(16, w: FontWeight.w900)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final n in const [3, 5, 7])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _RoundChip(
                        n: n,
                        selected: _rounds == n,
                        onTap: () => setState(() => _rounds = n),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('الألعاب', style: _t(16, w: FontWeight.w900)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ModeChip(
                    label: 'عشوائية 🎲',
                    selected: _random,
                    onTap: () => setState(() => _random = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeChip(
                    label: 'اختارها بنفسك',
                    selected: !_random,
                    onTap: () => setState(() => _random = false),
                  ),
                ),
              ],
            ),
            if (!_random) ...[
              const SizedBox(height: 8),
              Text(
                'اختار $_rounds ألعاب (${_picked.length}/$_rounds)',
                style: _t(12, w: FontWeight.w700)
                    .copyWith(color: FlatColors.ink.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.82,
                ),
                itemCount: arcade.length,
                itemBuilder: (context, i) {
                  final g = arcade[i];
                  final sel = _picked.contains(g.title);
                  return _PickCard(
                    title: g.title,
                    cover: ArcadeSectionScreen.covers[g.title],
                    emoji: ArcadeSectionScreen.emojiOf(g.title),
                    selected: sel,
                    order:
                        sel ? _picked.toList().indexOf(g.title) + 1 : null,
                    onTap: () => setState(() {
                      if (sel) {
                        _picked.remove(g.title);
                      } else if (_picked.length < _rounds) {
                        _picked.add(g.title);
                      }
                    }),
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _canStart ? _start : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlatColors.tilePastels[4],
                  disabledBackgroundColor: FlatColors.border,
                  foregroundColor: FlatColors.ink,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('ابدأ الكأس 🏆', style: _t(18, w: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundChip extends StatelessWidget {
  final int n;
  final bool selected;
  final VoidCallback onTap;
  const _RoundChip(
      {required this.n, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        decoration: BoxDecoration(
          color: selected ? FlatColors.tilePastels[0] : FlatColors.tileWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? FlatColors.tilePastels[0] : FlatColors.border,
              width: 2),
        ),
        child: Center(
          child: Text(
            '$n',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : FlatColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48,
        decoration: BoxDecoration(
          color: selected ? FlatColors.tilePastels[1] : FlatColors.tileWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? FlatColors.tilePastels[1] : FlatColors.border,
              width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : FlatColors.ink,
            ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
          ),
        ),
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  final String title;
  final String? cover;
  final String emoji;
  final bool selected;
  final int? order;
  final VoidCallback onTap;
  const _PickCard({
    required this.title,
    required this.cover,
    required this.emoji,
    required this.selected,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: FlatColors.tileWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? FlatColors.tilePastels[3] : FlatColors.border,
            width: selected ? 3 : 2,
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    child: cover != null
                        ? Image.asset(cover!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            opacity: AlwaysStoppedAnimation(
                                selected ? 1.0 : 0.85))
                        : Center(
                            child: Text(emoji,
                                style: const TextStyle(
                                    fontSize: 34,
                                    fontFamilyFallback: [
                                      'Noto Color Emoji'
                                    ]))),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: FlatColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            if (selected && order != null)
              Positioned(
                top: 6,
                right: 6,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: FlatColors.tilePastels[3],
                  child: Text('$order',
                      style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

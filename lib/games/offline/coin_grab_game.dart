import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/funky_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import 'coin_grab_logic.dart';

/// لمّ الفلوس: 2-4 players, rotating claw arms, tap to grab coins.
class CoinGrabGame extends StatefulWidget {
  const CoinGrabGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<CoinGrabGame> createState() => _CoinGrabGameState();
}

enum _CoinPhase { pickPlayers, playing, over }

class _CoinGrabGameState extends State<CoinGrabGame> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  _CoinPhase _phase = _CoinPhase.pickPlayers;
  late CoinGrabMatch _match;
  Timer? _ticker;
  String _banner = '';

  static const List<Color> _colors = [
    FunkyColors.coral,
    FunkyColors.cyan,
    FunkyColors.lime,
    FunkyColors.pink,
  ];

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startMatch(int players) {
    _ticker?.cancel();
    setState(() {
      _match = CoinGrabMatch(
        playerCount: players,
        random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
      );
      _banner = 'دوس لما دراعك يعدي على فلوس! 🪙';
      _phase = _CoinPhase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted || _phase != _CoinPhase.playing) return;
      setState(() {
        _match.tick();
        if (_match.isOver) {
          _ticker?.cancel();
          _phase = _CoinPhase.over;
        }
      });
    });
  }

  void _grab(int i) {
    if (_phase != _CoinPhase.playing) return;
    final got = _match.grab(i);
    setState(() {
      _banner = got > 0
          ? 'لاعب ${i + 1} لمّ $got جنيه! 🪙'
          : 'لاعب ${i + 1} مسك هوا 😅';
      if (_match.isOver) {
        _ticker?.cancel();
        _phase = _CoinPhase.over;
      }
    });
  }

  Widget _buildPicker() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'كام لاعب؟',
            style: GoogleFonts.cairo(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
          const SizedBox(height: 20),
          for (final n in [2, 3, 4])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: 200,
                child: FilledButton(
                  onPressed: () => _startMatch(n),
                  child: Text(
                    '$n لاعبين',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ).copyWith(fontFamilyFallback: _emojiFallback),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _scoreChip(int i) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _colors[i].withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _colors[i], width: 2),
          ),
          child: Center(
            child: Text(
              '${_match.scores[i]}',
              style: GoogleFonts.cairo(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ).copyWith(fontFamilyFallback: _emojiFallback),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'لاعب ${i + 1}',
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ).copyWith(fontFamilyFallback: _emojiFallback),
        ),
      ],
    );
  }

  Widget _grabButton(int i) {
    final active = _phase == _CoinPhase.playing;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _colors[i],
            disabledBackgroundColor: _colors[i].withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: active ? () => _grab(i) : null,
          child: Text(
            'لاعب ${i + 1} 🪙',
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
        ),
      ),
    );
  }

  Widget _buildOver() {
    final w = _match.winner();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (w != null)
          VictoryFriends(winnerName: 'لاعب ${w + 1}')
        else
          Text(
            'تعادل! الكل لمّ نفس الفلوس 🪙',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _phase = _CoinPhase.pickPlayers),
          child: Text(
            'العبوا تاني 🪙',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return GameIntroWidget(
        title: 'لمّ الفلوس',
        description:
            '٢-٤ لاعبين على نفس الموبايل. دراع كل لاعب بيلف حوالين القاعدة بتاعته.. دوس لما يعدي على عملة عشان تلمّها. الدهبية بعشرة! أغنى واحد لما الكوم يخلص يكسب 🪙',
        icon: '🪙',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    final players = _phase == _CoinPhase.pickPlayers ? 0 : _match.playerCount;
    return OfflineGameScaffold(
      title: 'لمّ الفلوس',
      backgroundColor: FunkyColors.bgDeep,
      body: SafeArea(
        child: _phase == _CoinPhase.pickPlayers
            ? _buildPicker()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (var i = 0; i < players; i++) _scoreChip(i)
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      _banner,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ).copyWith(fontFamilyFallback: _emojiFallback),
                    ),
                  ),
                  Expanded(
                    child: _phase == _CoinPhase.over
                        ? Center(child: _buildOver())
                        : Padding(
                            padding: const EdgeInsets.all(12),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: CustomPaint(
                                painter: _CoinArenaPainter(
                                  match: _match,
                                  colors: _colors,
                                ),
                              ),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                    child: Row(
                      children: [
                        for (var i = 0; i < players; i++) _grabButton(i)
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CoinArenaPainter extends CustomPainter {
  _CoinArenaPainter({required this.match, required this.colors});

  final CoinGrabMatch match;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    Offset at(double x, double y) => Offset(x * w, y * w);

    final bg = Paint()
      ..color = const Color(0xFF14102E)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      bg,
    );

    // coins
    for (final c in match.coins) {
      final center = at(c.x, c.y);
      final (fill, rim, r) = switch (c.value) {
        10 => (const Color(0xFFFFD64A), const Color(0xFFB8860B), 11.0),
        5 => (const Color(0xFFC0C8D8), const Color(0xFF7A8494), 9.0),
        _ => (const Color(0xFFE8A05C), const Color(0xFF9C6633), 7.0),
      };
      canvas.drawCircle(center, r, Paint()..color = rim);
      canvas.drawCircle(center, r - 2, Paint()..color = fill);
    }

    // bases, arms, tips
    for (var p = 0; p < match.playerCount; p++) {
      final base = at(match.baseOf(p).x, match.baseOf(p).y);
      final tip = at(match.armTipOf(p).x, match.armTipOf(p).y);
      final col = colors[p];
      canvas.drawCircle(
        base,
        CoinGrabMatch.armRadius * w,
        Paint()
          ..color = col.withValues(alpha: 0.10)
          ..style = PaintingStyle.fill,
      );
      canvas.drawLine(
        base,
        tip,
        Paint()
          ..color = col
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(base, 10, Paint()..color = col);
      canvas.drawCircle(tip, 9, Paint()..color = Colors.white);
      canvas.drawCircle(tip, 6, Paint()..color = col);
    }
  }

  @override
  bool shouldRepaint(_CoinArenaPainter oldDelegate) => true;
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/funky_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import 'tug_of_war_logic.dart';

/// شد الحبل: 2-4 players, one timing button each.
class TugOfWarGame extends StatefulWidget {
  const TugOfWarGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<TugOfWarGame> createState() => _TugOfWarGameState();
}

enum _TugPhase { pickPlayers, playing, over }

class _TugOfWarGameState extends State<TugOfWarGame> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  _TugPhase _phase = _TugPhase.pickPlayers;
  late TugMatch _match;
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
      _match = TugMatch(
        playerCount: players,
        random:
            widget.randomSeed != null ? Random(widget.randomSeed!) : null,
      );
      _banner = 'دوس لما المؤشر يبقى في النص! 💪';
      _phase = _TugPhase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted || _phase != _TugPhase.playing) return;
      setState(() {
        _match.tick();
        if (_match.isOver) {
          _ticker?.cancel();
          _phase = _TugPhase.over;
        }
      });
    });
  }

  void _tap(int i) {
    if (_phase != _TugPhase.playing) return;
    final grade = _match.tap(i);
    setState(() {
      _banner = switch (grade) {
        'perfect' => 'لاعب ${i + 1} شدها صح! 💪',
        'ok' => 'لاعب ${i + 1} شد خفيف',
        _ => 'لاعب ${i + 1} دوس غلط 😬',
      };
      if (_match.isOver) {
        _ticker?.cancel();
        _phase = _TugPhase.over;
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

  Widget _timingBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const greenW = TugMatch.perfectWindow * 2;
        const okW = TugMatch.okWindow * 2;
        return SizedBox(
          height: 26,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: w * (0.5 - okW / 2),
                width: w * okW,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: FunkyColors.amber.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: w * (0.5 - greenW / 2),
                width: w * greenW,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: FunkyColors.lime.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: (w * _match.phase - 4).clamp(0.0, w - 8),
                top: 2,
                bottom: 2,
                child: Container(
                  width: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArena() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _TugPainter(_match, _colors),
        );
      },
    );
  }

  Widget _pullButton(int i) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _colors[i],
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _phase == _TugPhase.playing ? () => _tap(i) : null,
          child: Text(
            'لاعب ${i + 1} 💪',
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VictoryFriends(winnerName: 'لاعب ${_match.winner! + 1}'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _phase = _TugPhase.pickPlayers),
          child: Text(
            'العبوا تاني 💪',
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
        title: 'شد الحبل',
        description:
            '٢-٤ لاعبين على نفس الموبايل. المؤشر بيجري يمين وشمال.. دوس لما يبقى في المنطقة الخضرا بالظبط عشان تشد الحبل لناحيتك. اللي يوصل بالعقدة لطرفه يكسب 💪',
        icon: '💪',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    final players = _phase == _TugPhase.pickPlayers ? 0 : _match.playerCount;
    return OfflineGameScaffold(
      title: 'شد الحبل',
      backgroundColor: FunkyColors.bgDeep,
      body: SafeArea(
        child: _phase == _TugPhase.pickPlayers
            ? _buildPicker()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: _timingBar(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
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
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _phase == _TugPhase.over
                          ? Center(child: _buildOver())
                          : _buildArena(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                    child: Row(
                      children: [
                        for (var i = 0; i < players; i++) _pullButton(i)
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TugPainter extends CustomPainter {
  _TugPainter(this.match, this.colors);

  final TugMatch match;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final side = min(size.width, size.height);
    final ox = (size.width - side) / 2;
    final oy = (size.height - side) / 2;
    final center = Offset(ox + side / 2, oy + side / 2);

    final bg = Paint()..color = const Color(0xFF0D1030);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(ox, oy, side, side), const Radius.circular(12)),
      bg,
    );

    // anchors at the four edges with player colors
    const anchors = [
      Offset(0.06, 0.5),
      Offset(0.94, 0.5),
      Offset(0.5, 0.08),
      Offset(0.5, 0.92),
    ];
    for (var p = 0; p < match.playerCount; p++) {
      final a = anchors[p];
      final c = Offset(ox + a.dx * side, oy + a.dy * side);
      canvas.drawCircle(
          c, side * 0.045, Paint()..color = colors[p].withValues(alpha: 0.9));
    }

    // rope from center to knot
    final knot = Offset(center.dx + match.kx * side * 0.42,
        center.dy + match.ky * side * 0.42);
    final rope = Paint()
      ..color = FunkyColors.amber
      ..strokeWidth = side * 0.015
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, knot, rope);
    canvas.drawCircle(center, side * 0.012, Paint()..color = Colors.white24);
    canvas.drawCircle(knot, side * 0.035, Paint()..color = FunkyColors.amber);
    canvas.drawCircle(
        knot, side * 0.02, Paint()..color = FunkyColors.magenta);
  }

  @override
  bool shouldRepaint(_TugPainter oldDelegate) => true;
}

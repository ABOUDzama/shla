import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';
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
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
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
            style: flatCairo(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: FlatColors.ink,
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
                    style: flatCairo(
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
                    color: FlatColors.tileWhite,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: FlatColors.border, width: 2),
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
                    color: FlatColors.tilePastels[4],
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
                    color: FlatColors.tilePastels[2],
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
                    color: FlatColors.ink,
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
            style: flatCairo(
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
        VictoryFriends(gameTitle: 'شد الحبل', winnerName: 'لاعب ${_match.winner! + 1}'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _phase = _TugPhase.pickPlayers),
          child: Text(
            'العبوا تاني 💪',
            style: flatCairo(
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
      backgroundColor: FlatColors.bg,
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
                      style: flatCairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: FlatColors.ink,
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

    final bg = Paint()..color = FlatColors.tileWhite;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(ox, oy, side, side), const Radius.circular(12)),
      bg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(ox, oy, side, side), const Radius.circular(12)),
      Paint()
        ..color = FlatColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // home ring at the center
    canvas.drawCircle(
        center,
        side * 0.06,
        Paint()
          ..color = FlatColors.ink.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = side * 0.008);

    final knot = Offset(center.dx + match.kx * side * 0.42,
        center.dy + match.ky * side * 0.42);

    // anchors at the four edges: cartoon arm + fist gripping a twisted rope
    const anchors = [
      Offset(0.06, 0.5),
      Offset(0.94, 0.5),
      Offset(0.5, 0.08),
      Offset(0.5, 0.92),
    ];
    for (var p = 0; p < match.playerCount; p++) {
      final a = anchors[p];
      final c = Offset(ox + a.dx * side, oy + a.dy * side);
      final col = colors[p];
      final dark = Color.lerp(col, Colors.black, 0.4)!;

      // twisted rope from fist to knot
      final ropePaint = Paint()
        ..color = const Color(0xFFDEB878)
        ..strokeWidth = side * 0.022
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c, knot, ropePaint);
      // rope twist marks
      final dir = (knot - c);
      final len = dir.distance;
      if (len > 0) {
        final unit = dir / len;
        final perp = Offset(-unit.dy, unit.dx);
        final twist = Paint()
          ..color = const Color(0xFFBE965A)
          ..strokeWidth = side * 0.006
          ..strokeCap = StrokeCap.round;
        for (var t = side * 0.06; t < len - side * 0.05; t += side * 0.045) {
          final m = c + unit * t;
          canvas.drawLine(
              m - perp * side * 0.011 + unit * side * 0.008,
              m + perp * side * 0.011 - unit * side * 0.008,
              twist);
        }
      }

      // arm: capsule sleeve in player color pointing at the knot
      final inward = (knot - c);
      final u = inward.distance > 0 ? inward / inward.distance : Offset.zero;
      final elbow = c - u * side * 0.02;
      final fist = c + u * side * 0.05;
      canvas.drawLine(
          elbow,
          fist,
          Paint()
            ..color = col
            ..strokeWidth = side * 0.05
            ..strokeCap = StrokeCap.round);
      // fist on the rope
      canvas.drawCircle(fist, side * 0.038, Paint()..color = col);
      canvas.drawCircle(
          fist,
          side * 0.038,
          Paint()
            ..color = dark
            ..style = PaintingStyle.stroke
            ..strokeWidth = side * 0.007);
      // knuckle lines
      for (var k = -1; k <= 1; k++) {
        final kp = fist + Offset(-u.dy, u.dx) * (k * side * 0.016);
        canvas.drawCircle(kp + u * side * 0.018, side * 0.008,
            Paint()..color = dark.withValues(alpha: 0.7));
      }
    }

    // knot
    canvas.drawCircle(knot, side * 0.038, Paint()..color = FlatColors.tilePastels[4]);
    canvas.drawCircle(
        knot,
        side * 0.038,
        Paint()
          ..color = FlatColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = side * 0.008);
    canvas.drawCircle(
        knot, side * 0.012, Paint()..color = const Color(0xFFFFF3C0));
  }

  @override
  bool shouldRepaint(_TugPainter oldDelegate) => true;
}

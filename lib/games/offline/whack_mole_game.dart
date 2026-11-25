import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/funky_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import 'whack_mole_logic.dart';

/// اضرب الخلد: 2-4 players, each whacks moles in their own 2x2 grid.
class WhackMoleGame extends StatefulWidget {
  const WhackMoleGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<WhackMoleGame> createState() => _WhackMoleGameState();
}

enum _MolePhase { pickPlayers, playing, over }

class _WhackMoleGameState extends State<WhackMoleGame> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  _MolePhase _phase = _MolePhase.pickPlayers;
  late WhackMoleMatch _match;
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
      _match = WhackMoleMatch(
        playerCount: players,
        random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
      );
      _banner = 'اضرب الخلد في المربع بتاعك بس! 🔨';
      _phase = _MolePhase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted || _phase != _MolePhase.playing) return;
      setState(() {
        _match.tick();
        if (_match.isOver) {
          _ticker?.cancel();
          _phase = _MolePhase.over;
        }
      });
    });
  }

  void _whack(int player, int hole) {
    if (_phase != _MolePhase.playing) return;
    final hit = _match.whack(player, hole);
    setState(() {
      _banner = hit
          ? 'لاعب ${player + 1} جابها! 🔨'
          : 'لاعب ${player + 1} ضرب في الفاضي 😅';
      if (_match.isOver) {
        _ticker?.cancel();
        _phase = _MolePhase.over;
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

  Widget _playerPanel(int p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'لاعب ${p + 1}: ${_match.scores[p]}',
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _colors[p],
          ).copyWith(fontFamilyFallback: _emojiFallback),
        ),
        const SizedBox(height: 4),
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.maxWidth;
              return GestureDetector(
                key: Key('mole_grid_$p'),
                onTapUp: (d) {
                  final half = side / 2;
                  final col = d.localPosition.dx >= half ? 1 : 0;
                  final row = d.localPosition.dy >= half ? 1 : 0;
                  _whack(p, row * 2 + col);
                },
                child: CustomPaint(
                  painter: _MoleGridPainter(
                    match: _match,
                    player: p,
                    color: _colors[p],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaying() {
    final players = _match.playerCount;
    final rows = (players / 2).ceil();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: LinearProgressIndicator(
            value: 1 - (_match.tickCount / _match.roundTicks).clamp(0.0, 1.0),
            backgroundColor: Colors.white10,
            color: FunkyColors.amber,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                for (var r = 0; r < rows; r++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var c = 0; c < 2; c++)
                          if (r * 2 + c < players)
                            Expanded(child: _playerPanel(r * 2 + c))
                          else
                            const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
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
            'تعادل! الكل ضرب نفس العدد 🔨',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
        const SizedBox(height: 12),
        for (var p = 0; p < _match.playerCount; p++)
          Text(
            'لاعب ${p + 1}: ${_match.scores[p]}',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _colors[p],
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _phase = _MolePhase.pickPlayers),
          child: Text(
            'العبوا تاني 🔨',
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
        title: 'اضرب الخلد',
        description:
            '٢-٤ لاعبين على نفس الموبايل. لكل لاعب مربع فيه ٤ جحور.. الخلد بيطلع وينزل بسرعة، اضربه في مربعك بس قبل ما يهرب! اللي يجيب أكتر عدد قبل ما الوقت يخلص يكسب 🔨',
        icon: '🔨',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    return OfflineGameScaffold(
      title: 'اضرب الخلد',
      backgroundColor: FunkyColors.bgDeep,
      body: SafeArea(
        child: _phase == _MolePhase.pickPlayers
            ? _buildPicker()
            : _phase == _MolePhase.playing
                ? _buildPlaying()
                : Center(child: _buildOver()),
      ),
    );
  }
}

class _MoleGridPainter extends CustomPainter {
  _MoleGridPainter({
    required this.match,
    required this.player,
    required this.color,
  });

  final WhackMoleMatch match;
  final int player;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final half = Size(size.width / 2, size.height / 2);
    for (var h = 0; h < WhackMoleMatch.holesPerPlayer; h++) {
      final ox = (h % 2) * half.width + half.width / 2;
      final oy = (h ~/ 2) * half.height + half.height / 2;
      final center = Offset(ox, oy);
      final r = half.width * 0.34;

      // hole
      canvas.drawOval(
        Rect.fromCenter(center: center, width: r * 2.1, height: r * 1.1),
        Paint()..color = const Color(0xFF0D0A22),
      );
      if (match.isUp(player, h)) {
        // mole: head + ears + eyes + nose
        final moleBase = center.translate(0, r * 0.32);
        final head = Rect.fromCenter(
            center: moleBase.translate(0, -r * 0.35),
            width: r * 1.5,
            height: r * 1.5);
        canvas.drawOval(head, Paint()..color = const Color(0xFFB08050));
        for (final dx in [-r * 0.55, r * 0.55]) {
          canvas.drawCircle(
            moleBase.translate(dx, -r * 1.05),
            r * 0.28,
            Paint()..color = const Color(0xFFB08050),
          );
          canvas.drawCircle(
            moleBase.translate(dx, -r * 1.05),
            r * 0.14,
            Paint()..color = const Color(0xFF7A5530),
          );
        }
        for (final dx in [-r * 0.3, r * 0.3]) {
          canvas.drawCircle(
            moleBase.translate(dx, -r * 0.5),
            r * 0.11,
            Paint()..color = const Color(0xFF201818),
          );
        }
        canvas.drawCircle(
          moleBase.translate(0, -r * 0.22),
          r * 0.14,
          Paint()..color = const Color(0xFFE87888),
        );
      }
      // grid frame in player color
      canvas.drawRect(
        Rect.fromLTWH(
          (h % 2) * half.width + 4,
          (h ~/ 2) * half.height + 4,
          half.width - 8,
          half.height - 8,
        ),
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_MoleGridPainter oldDelegate) => true;
}

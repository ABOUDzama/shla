import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/funky_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import 'tank_battle_logic.dart';

/// دبابات الشلة: 2-4 tanks on one phone, one fire button per player.
class TankBattleGame extends StatefulWidget {
  const TankBattleGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<TankBattleGame> createState() => _TankBattleGameState();
}

enum _TankPhase { pickPlayers, playing, over }

class _TankBattleGameState extends State<TankBattleGame> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  _TankPhase _phase = _TankPhase.pickPlayers;
  late TankBattleMatch _match;
  Timer? _ticker;

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
      _match = TankBattleMatch(
        playerCount: players,
        random:
            widget.randomSeed != null ? Random(widget.randomSeed!) : null,
      );
      _phase = _TankPhase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted || _phase != _TankPhase.playing) return;
      setState(() {
        _match.tick();
        if (_match.isOver) {
          _ticker?.cancel();
          _phase = _TankPhase.over;
        }
      });
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

  Widget _scorePill(int i) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _colors[i].withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _colors[i]),
      ),
      child: Text(
        'لاعب ${i + 1}: ${_match.scores[i]}',
        style: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ).copyWith(fontFamilyFallback: _emojiFallback),
      ),
    );
  }

  Widget _fireButton(int i) {
    final active = _phase == _TankPhase.playing && _match.cooldowns[i] == 0;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _colors[i],
            disabledBackgroundColor: _colors[i].withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _phase == _TankPhase.playing
              ? () => setState(() => _match.fire(i))
              : null,
          child: Text(
            active ? 'لاعب ${i + 1} 🎯' : 'لاعب ${i + 1} ...',
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
          onPressed: () => setState(() => _phase = _TankPhase.pickPlayers),
          child: Text(
            'العبوا تاني 💥',
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
        title: 'دبابات الشلة',
        description:
            '٢-٤ لاعبين على نفس الموبايل. المدفع بيلف لوحده وانت بتحدد لحظة الضرب بزرار واحد. أصيب دبابات صحابك واجمع ٥ نقط قبلهم 💥',
        icon: '💥',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    final players = _phase == _TankPhase.pickPlayers ? 0 : _match.playerCount;
    return OfflineGameScaffold(
      title: 'دبابات الشلة',
      backgroundColor: FunkyColors.bgDeep,
      body: SafeArea(
        child: _phase == _TankPhase.pickPlayers
            ? _buildPicker()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (var i = 0; i < players; i++) _scorePill(i)
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _phase == _TankPhase.over
                          ? Center(child: _buildOver())
                          : LayoutBuilder(
                              builder: (context, constraints) => CustomPaint(
                                size: Size(constraints.maxWidth,
                                    constraints.maxHeight),
                                painter: _TankPainter(_match, _colors),
                              ),
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                    child: Row(
                      children: [
                        for (var i = 0; i < players; i++) _fireButton(i)
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TankPainter extends CustomPainter {
  _TankPainter(this.match, this.colors);

  final TankBattleMatch match;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final side = min(size.width, size.height);
    final ox = (size.width - side) / 2;
    final oy = (size.height - side) / 2;
    Offset at(double x, double y) => Offset(ox + x * side, oy + y * side);

    final bg = Paint()..color = const Color(0xFF0D1030);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(ox, oy, side, side), const Radius.circular(12)),
      bg,
    );

    // tanks
    for (var p = 0; p < match.playerCount; p++) {
      final a = TankBattleMatch.anchors[p];
      final c = at(a.x, a.y);
      final r = TankBattleMatch.tankRadius * side;
      final body = Paint()..color = colors[p];
      canvas.drawCircle(c, r, body);
      // turret line showing current aim
      final aim = match.aimAngle(p);
      final barrel = Paint()
        ..color = Colors.white
        ..strokeWidth = r * 0.35
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          c, c + Offset(cos(aim), sin(aim)) * r * 1.6, barrel);
    }

    // shells
    final shellPaint = Paint()..color = FunkyColors.amber;
    for (final s in match.shells) {
      canvas.drawCircle(at(s.x, s.y), side * 0.012, shellPaint);
    }
  }

  @override
  bool shouldRepaint(_TankPainter oldDelegate) => true;
}

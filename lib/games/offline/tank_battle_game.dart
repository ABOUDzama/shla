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

    // ground detail: grid dots + faint craters
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var gy = 0.1; gy < 1; gy += 0.1) {
      for (var gx = 0.1; gx < 1; gx += 0.1) {
        canvas.drawCircle(at(gx, gy), side * 0.004, dot);
      }
    }

    // tanks: tracks, hull, turret, barrel
    for (var p = 0; p < match.playerCount; p++) {
      final a = TankBattleMatch.anchors[p];
      final c = at(a.x, a.y);
      final r = TankBattleMatch.tankRadius * side;
      final col = colors[p];
      final dark = Color.lerp(col, Colors.black, 0.45)!;
      final light = Color.lerp(col, Colors.white, 0.25)!;
      final aim = match.aimAngle(p);

      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(aim);
      // tracks
      for (final ty in [-r * 0.62, r * 0.32]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-r * 1.05, ty, r * 1.7, r * 0.3),
            Radius.circular(r * 0.15),
          ),
          Paint()..color = dark,
        );
        for (var wx = -r * 0.85; wx <= r * 0.55; wx += r * 0.35) {
          canvas.drawCircle(
            Offset(wx, ty + r * 0.15),
            r * 0.08,
            Paint()..color = Colors.white24,
          );
        }
      }
      // hull
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-r * 0.95, -r * 0.45, r * 1.5, r * 0.9),
          Radius.circular(r * 0.2),
        ),
        Paint()..color = col,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-r * 0.95, -r * 0.45, r * 0.5, r * 0.9),
          Radius.circular(r * 0.2),
        ),
        Paint()..color = light.withValues(alpha: 0.5),
      );
      // turret dome
      canvas.drawCircle(Offset(-r * 0.1, 0), r * 0.42, Paint()..color = col);
      canvas.drawCircle(
          Offset(-r * 0.1, 0), r * 0.42, Paint()
        ..color = dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08);
      // barrel
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r * 0.15, -r * 0.11, r * 1.05, r * 0.22),
          Radius.circular(r * 0.08),
        ),
        Paint()..color = dark,
      );
      canvas.drawCircle(Offset(r * 1.2, 0), r * 0.14, Paint()..color = dark);
      canvas.restore();
    }

    // shells with motion trails
    for (final s in match.shells) {
      final pos = at(s.x, s.y);
      final trail = Paint()
        ..color = FunkyColors.amber.withValues(alpha: 0.5)
        ..strokeWidth = side * 0.008
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(pos, pos - Offset(s.dx, s.dy) * side * 6, trail);
      canvas.drawCircle(
          pos, side * 0.014, Paint()..color = FunkyColors.amber);
      canvas.drawCircle(
          pos, side * 0.007, Paint()..color = const Color(0xFFFFF3C0));
    }
  }

  @override
  bool shouldRepaint(_TankPainter oldDelegate) => true;
}

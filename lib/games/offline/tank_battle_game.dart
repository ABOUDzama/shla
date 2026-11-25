import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/funky_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import 'tank_battle_logic.dart';

/// دبابات الشلة: reference-faithful one-button tanks.
/// Hold your button to steer, release to fire. One hit kills.
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
      _match = TankBattleMatch(
        playerCount: players,
        random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
      );
      _banner = 'دوس مطوّل عشان تلفّ.. وسيب عشان تضرب! 🎯';
      _phase = _TankPhase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 60), (_) {
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

  void _holdStart(int i) {
    if (_phase != _TankPhase.playing) return;
    setState(() => _match.holdStart(i));
  }

  void _holdEnd(int i) {
    if (_phase != _TankPhase.playing) return;
    final fired = _match.holdRelease(i);
    setState(() {
      _banner = fired ? 'لاعب ${i + 1} ضرب! 💥' : _banner;
      if (_match.isOver) {
        _ticker?.cancel();
        _phase = _TankPhase.over;
      }
    });
  }


  /// Test hook: current match (read-only) for state assertions.
  @visibleForTesting
  TankBattleMatch get debugMatch => _match;

  /// Test hook: jump straight to the over screen with [winner] as victor.
  @visibleForTesting
  void debugForceWin(int winner) {
    _ticker?.cancel();
    setState(() {
      for (var p = 0; p < _match.playerCount; p++) {
        if (p != winner && _match.alive[p]) {
          _match.alive[p] = false;
          _match.destroyedAt.add(_match.tickCount);
        }
      }
      _match.winner = winner;
      _phase = _TankPhase.over;
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

  Widget _statusChip(int i) {
    final aliveNow = _match.alive[i];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: aliveNow
                ? _colors[i].withValues(alpha: 0.35)
                : Colors.white10,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: aliveNow ? _colors[i] : Colors.white24,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              aliveNow ? '🛡' : '💥',
              style: const TextStyle(fontSize: 18)
                  .copyWith(fontFamilyFallback: _emojiFallback),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'لاعب ${i + 1}',
          style: GoogleFonts.cairo(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: aliveNow ? Colors.white : Colors.white38,
          ).copyWith(fontFamilyFallback: _emojiFallback),
        ),
      ],
    );
  }

  /// Circular corner pad: hold to steer, release to fire. Top-corner pads
  /// are rotated 180 degrees so they face the player across the phone.
  Widget _cornerPad(int i) {
    final active = _phase == _TankPhase.playing && _match.alive[i];
    final held = active && _match.holding[i];
    return GestureDetector(
        onTapDown: active ? (_) => _holdStart(i) : null,
        onTapUp: active ? (_) => _holdEnd(i) : null,
        onTapCancel: active ? () => _holdEnd(i) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: !active
                ? _colors[i].withValues(alpha: 0.18)
                : held
                    ? Colors.white
                    : _colors[i],
            border: Border.all(
              color: held ? _colors[i] : Colors.white.withValues(alpha: 0.35),
              width: held ? 4 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _colors[i].withValues(alpha: active ? 0.5 : 0.15),
                blurRadius: held ? 18 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'لاعب ${i + 1} 🎯',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w800,
                color: held
                    ? _colors[i]
                    : active
                        ? Colors.black87
                        : Colors.white38,
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
        if (_match.winner != null)
          VictoryFriends(winnerName: 'لاعب ${_match.winner! + 1}')
        else
          Text(
            'مفيش ناجي! الكل اتدمر 💥',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _phase = _TankPhase.pickPlayers),
          child: Text(
            'العبوا تاني 🎯',
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
            '٢-٤ دبابات في ساحة واحدة. دبابتك ماشية لوحدها: دوس مطوّل على زرارك عشان تلفّ بيها، وسيب الزرار عشان تضرب قذيفة. القذيفة بترتد من الحيطان، وضربة واحدة تدمّر أي دبابة.. حتى دبابتك! آخر دبابة عايشة تكسب 🎯',
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
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (var i = 0; i < players; i++) _statusChip(i)
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
                    child: _phase == _TankPhase.over
                        ? Center(child: _buildOver())
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final side =
                                  min(constraints.maxWidth - 16, 420.0);
                              return Stack(
                                children: [
                                  Center(
                                    child: SizedBox(
                                      width: side,
                                      height: side,
                                      child: CustomPaint(
                                        painter:
                                            _TankPainter(_match, _colors),
                                      ),
                                    ),
                                  ),
                                  for (var i = 0; i < players; i++)
                                    Positioned(
                                      left: _match.xs[i] < 0.5 ? 6 : null,
                                      right: _match.xs[i] < 0.5 ? null : 6,
                                      top: _match.ys[i] < 0.5 ? 6 : null,
                                      bottom: _match.ys[i] < 0.5 ? null : 6,
                                      child: _cornerPad(i),
                                    ),
                                ],
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
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
    final w = size.width;
    Offset at(double x, double y) => Offset(x * w, y * w);

    // field
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      Paint()..color = const Color(0xFF16301E),
    );
    // grid dots
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (var gy = 0.08; gy < 1; gy += 0.08) {
      for (var gx = 0.08; gx < 1; gx += 0.08) {
        canvas.drawCircle(at(gx, gy), w * 0.004, dot);
      }
    }
    // walls border
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      Paint()
        ..color = const Color(0xFF3E5A44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012,
    );

    // obstacles: sand-colored blocks with darker rim
    for (final o in match.arena.obstacles) {
      final rect = Rect.fromLTWH(
          o.x * w, o.y * w, o.w * w, o.h * w);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(w * 0.015)),
        Paint()..color = const Color(0xFF8A6B3D),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(w * 0.008), Radius.circular(w * 0.01)),
        Paint()..color = const Color(0xFFA8844E),
      );
    }

    // tanks (destroyed: scorch mark)
    for (var p = 0; p < match.playerCount; p++) {
      final c = at(match.xs[p], match.ys[p]);
      final r = TankBattleMatch.tankRadius * w;
      final col = colors[p];
      if (!match.alive[p]) {
        canvas.drawCircle(c, r * 0.9,
            Paint()..color = Colors.black.withValues(alpha: 0.55));
        canvas.drawCircle(
            c,
            r * 0.9,
            Paint()
              ..color = const Color(0xFF5A4A3A)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        continue;
      }
      final dark = Color.lerp(col, Colors.black, 0.45)!;
      final light = Color.lerp(col, Colors.white, 0.25)!;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(match.headings[p]);
      for (final ty in [-r * 0.62, r * 0.32]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-r * 1.05, ty, r * 1.7, r * 0.3),
            Radius.circular(r * 0.15),
          ),
          Paint()..color = dark,
        );
      }
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
      canvas.drawCircle(Offset(-r * 0.1, 0), r * 0.42, Paint()..color = col);
      canvas.drawCircle(
          Offset(-r * 0.1, 0),
          r * 0.42,
          Paint()
            ..color = dark
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.08);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r * 0.15, -r * 0.11, r * 1.05, r * 0.22),
          Radius.circular(r * 0.08),
        ),
        Paint()..color = dark,
      );
      canvas.drawCircle(Offset(r * 1.2, 0), r * 0.14, Paint()..color = dark);
      canvas.restore();
      // holding ring: shows this player is steering
      if (match.holding[p]) {
        canvas.drawCircle(
            c,
            r * 1.5,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5);
      }
    }

    // shells with trails
    for (final s in match.shells) {
      final pos = at(s.x, s.y);
      canvas.drawLine(
        pos,
        pos - Offset(s.dx, s.dy) * w * 0.05,
        Paint()
          ..color = FunkyColors.amber.withValues(alpha: 0.5)
          ..strokeWidth = w * 0.008
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(pos, w * 0.014, Paint()..color = FunkyColors.amber);
      canvas.drawCircle(
          pos, w * 0.007, Paint()..color = const Color(0xFFFFF3C0));
    }
  }

  @override
  bool shouldRepaint(_TankPainter oldDelegate) => true;
}

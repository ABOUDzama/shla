import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/funky_theme.dart';
import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import 'tank_battle_logic.dart';

/// دبابات الشلة: reference-faithful one-button tanks.
/// Hold your corner pad to steer, release to fire. One hit destroys.
/// 1-4 humans, optional bot fill to 4.
class TankBattleGame extends StatefulWidget {
  const TankBattleGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<TankBattleGame> createState() => _TankBattleGameState();
}

enum _TankPhase { pickPlayers, pickBots, playing, over }

class _TankBattleGameState extends State<TankBattleGame> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  _TankPhase _phase = _TankPhase.pickPlayers;
  late TankBattleMatch _match;
  Timer? _ticker;
  int _humans = 2;

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

  void _startMatch(int humans, bool withBots) {
    _ticker?.cancel();
    setState(() {
      _humans = humans;
      _match = TankBattleMatch(
        playerCount: withBots ? 4 : humans,
        humanCount: humans,
        random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
      );
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
    setState(() {
      _match.holdRelease(i);
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
          _match.deathTick[p] = _match.tickCount;
        }
      }
      _match.winner = winner;
      _phase = _TankPhase.over;
    });
  }

  Widget _bigChoice(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: 220,
        child: FilledButton(
          onPressed: onTap,
          child: Text(
            label,
            style: flatCairo(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
        ),
      ),
    );
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
              color: Colors.white,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
          const SizedBox(height: 20),
          _bigChoice('لاعب واحد', () {
            _humans = 1;
            setState(() => _phase = _TankPhase.pickBots);
          }),
          for (final n in [2, 3, 4])
            _bigChoice('$n لاعبين', () {
              _humans = n;
              if (n == 4) {
                _startMatch(4, false);
              } else {
                setState(() => _phase = _TankPhase.pickBots);
              }
            }),
        ],
      ),
    );
  }

  Widget _buildBotsPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'نضيف بوتات؟',
            style: flatCairo(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
          const SizedBox(height: 8),
          Text(
            'البوتات بتكمل الأربع لاعبين',
            style: flatCairo(
              fontSize: 14,
              color: Colors.white70,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () => _startMatch(_humans, true)),
          _bigChoice('لا', () => _startMatch(_humans, false)),
        ],
      ),
    );
  }

  /// Circular corner pad: hold to steer, release to fire.
  Widget _cornerPad(int i) {
    final active = _phase == _TankPhase.playing && _match.alive[i];
    final held = active && _match.holding[i];
    return GestureDetector(
      onTapDown: active ? (_) => _holdStart(i) : null,
      onTapUp: active ? (_) => _holdEnd(i) : null,
      onTapCancel: active ? () => _holdEnd(i) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 84,
        height: 84,
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
            'لاعب ${i + 1}',
            textAlign: TextAlign.center,
            style: flatCairo(
              fontSize: 13,
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
    final practice = _match.practice;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (practice)
          Text(
            'انتهت جولة التدريب 👏',
            style: flatCairo(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          )
        else if (_match.winner != null)
          VictoryFriends(
              winnerName: _match.winner! < _humans
                  ? 'لاعب ${_match.winner! + 1}'
                  : 'بوت ${_match.winner! + 1}')
        else
          Text(
            'مفيش ناجي! الكل اتدمر 💥',
            style: flatCairo(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => practice
              ? _startMatch(1, false)
              : setState(() => _phase = _TankPhase.pickPlayers),
          child: Text(
            practice ? 'تدريب تاني 🎯' : 'العبوا تاني 🎯',
            style: flatCairo(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _phase = _TankPhase.pickPlayers),
          child: Text(
            'رجوع',
            style: flatCairo(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
        ),
      ],
    );
  }

  /// Small floating header during solo practice: label, countdown, exit.
  Widget _practiceTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'تدريب · باقي ${_match.remainingSeconds} ث',
            style: flatCairo(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              _ticker?.cancel();
              setState(() => _phase = _TankPhase.pickPlayers);
            },
            child: Text(
              'إنهاء',
              style: flatCairo(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: FunkyColors.coral,
              ).copyWith(fontFamilyFallback: _emojiFallback),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return GameIntroWidget(
        title: 'دبابات الشلة',
        description:
            'من ١ لـ٤ لاعبين في ساحة واحدة، وتقدر تكمل ببوتات. دبابتك ماشية لوحدها: دوس مطوّل على الزرار بتاعك في ركنك عشان تلفّ بيها، وسيبه عشان تضرب قذيفة. القذيفة بترتد من الحيطان، وضربة واحدة تدمّر أي دبابة.. حتى دبابتك! آخر دبابة عايشة تكسب 🎯',
        icon: '💥',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    final humans = (_phase == _TankPhase.playing || _phase == _TankPhase.over)
        ? _match.humanCount
        : 0;
    return OfflineGameScaffold(
      title: 'دبابات الشلة',
      backgroundColor: FunkyColors.bgDeep,
      body: SafeArea(
        child: switch (_phase) {
          _TankPhase.pickPlayers => _buildPicker(),
          _TankPhase.pickBots => _buildBotsPrompt(),
          _TankPhase.over => Center(child: _buildOver()),
          _TankPhase.playing => LayoutBuilder(
              builder: (context, constraints) {
                final side = min(constraints.maxWidth - 12,
                        constraints.maxHeight - 12)
                    .clamp(0.0, 520.0);
                return Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        width: side,
                        height: side,
                        child: CustomPaint(
                          painter: _TankPainter(_match, _colors),
                        ),
                      ),
                    ),
                    for (var i = 0; i < humans; i++)
                      Positioned(
                        left: _match.xs[i] < 0.5 ? 8 : null,
                        right: _match.xs[i] < 0.5 ? null : 8,
                        top: _match.ys[i] < 0.5 ? 8 : null,
                        bottom: _match.ys[i] < 0.5 ? null : 8,
                        child: _cornerPad(i),
                      ),
                    if (_match.practice)
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(child: _practiceTag()),
                      ),
                  ],
                );
              },
            ),
        },
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
    final rr = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(w * 0.04));

    // sand field
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFE9C97F));
    // sand speckles
    final dot = Paint()..color = const Color(0x33A67C3D);
    for (var gy = 0.05; gy < 1; gy += 0.05) {
      for (var gx = ((gy * 100).round() % 2 == 0) ? 0.05 : 0.075;
          gx < 1;
          gx += 0.1) {
        canvas.drawCircle(at(gx, gy), w * 0.004, dot);
      }
    }
    // wooden border
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFF8A5A33)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.018,
    );

    // brick obstacles
    for (final o in match.arena.obstacles) {
      final rect = Rect.fromLTWH(o.x * w, o.y * w, o.w * w, o.h * w);
      final orr = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.012));
      canvas.drawRRect(orr, Paint()..color = const Color(0xFFB4553C));
      // brick lines
      final brick = Paint()
        ..color = const Color(0xFF8F3E2A)
        ..strokeWidth = w * 0.004;
      final midY = rect.center.dy;
      canvas.drawLine(
          Offset(rect.left + 4, midY), Offset(rect.right - 4, midY), brick);
      final midX = rect.center.dx;
      canvas.drawLine(Offset(midX, rect.top + 4),
          Offset(midX, rect.center.dy - 2), brick);
      canvas.drawLine(Offset(midX, rect.center.dy + 2),
          Offset(midX, rect.bottom - 4), brick);
      // top highlight
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.22),
            Radius.circular(w * 0.012)),
        Paint()..color = const Color(0xFFD4765C),
      );
    }

    // tanks (destroyed: explosion flash then scorch mark)
    for (var p = 0; p < match.playerCount; p++) {
      final c = at(match.xs[p], match.ys[p]);
      final r = TankBattleMatch.tankRadius * w;
      final col = colors[p];
      if (!match.alive[p]) {
        final sinceDeath =
            match.tickCount - (match.deathTick[p] ?? -999);
        if (sinceDeath >= 0 && sinceDeath < 10) {
          final t = sinceDeath / 10.0;
          canvas.drawCircle(
              c,
              r * (1.2 + t * 2.2),
              Paint()
                ..color = const Color(0xFFFFC233)
                    .withValues(alpha: (1 - t) * 0.8));
          canvas.drawCircle(
              c,
              r * (0.8 + t * 1.4),
              Paint()
                ..color = Colors.white.withValues(alpha: (1 - t) * 0.9));
        }
        canvas.drawCircle(
            c, r * 0.9, Paint()..color = Colors.black.withValues(alpha: 0.55));
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
      // tracks
      for (final ty in [-r * 0.62, r * 0.32]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-r * 1.05, ty, r * 1.7, r * 0.3),
            Radius.circular(r * 0.15),
          ),
          Paint()..color = dark,
        );
        // track wheels
        for (var wx = -r * 0.85; wx <= r * 0.45; wx += r * 0.44) {
          canvas.drawCircle(Offset(wx, ty + r * 0.15), r * 0.09,
              Paint()..color = Colors.black.withValues(alpha: 0.5));
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
      // turret + star decal
      canvas.drawCircle(Offset(-r * 0.1, 0), r * 0.42, Paint()..color = col);
      canvas.drawCircle(
          Offset(-r * 0.1, 0),
          r * 0.42,
          Paint()
            ..color = dark
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.08);
      _star(canvas, Offset(-r * 0.1, 0), r * 0.2,
          Paint()..color = Colors.white.withValues(alpha: 0.85));
      // barrel + muzzle
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r * 0.15, -r * 0.11, r * 1.05, r * 0.22),
          Radius.circular(r * 0.08),
        ),
        Paint()..color = dark,
      );
      canvas.drawCircle(Offset(r * 1.2, 0), r * 0.16, Paint()..color = dark);
      canvas.drawCircle(Offset(r * 1.2, 0), r * 0.08, Paint()..color = col);
      // antenna
      canvas.drawLine(Offset(-r * 0.7, -r * 0.3), Offset(-r * 1.1, -r * 1.0),
          Paint()
            ..color = dark
            ..strokeWidth = r * 0.05);
      canvas.drawCircle(Offset(-r * 1.1, -r * 1.0), r * 0.08,
          Paint()..color = const Color(0xFFFFC233));
      canvas.restore();
      // holding ring: this player is steering
      if (match.holding[p]) {
        canvas.drawCircle(
            c,
            r * 1.55,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.55)
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

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final a = -pi / 2 + i * 4 * pi / 5;
      final pt = Offset(c.dx + cos(a) * r, c.dy + sin(a) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TankPainter oldDelegate) => true;
}

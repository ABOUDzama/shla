import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import 'snow_brawl_logic.dart';

/// معركة التلج: 2-4 forts, one throw button per player.
class SnowBrawlGame extends StatefulWidget {
  const SnowBrawlGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<SnowBrawlGame> createState() => _SnowBrawlGameState();
}

enum _SnowPhase { pickPlayers, playing, over }

class _SnowBrawlGameState extends State<SnowBrawlGame> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  _SnowPhase _phase = _SnowPhase.pickPlayers;
  late SnowBrawlMatch _match;
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
      _match = SnowBrawlMatch(
        playerCount: players,
        random:
            widget.randomSeed != null ? Random(widget.randomSeed!) : null,
      );
      _banner = 'دوس لما عدّاد القوة يوصل للعلامة! ❄';
      _phase = _SnowPhase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted || _phase != _SnowPhase.playing) return;
      setState(() {
        _match.tick();
        if (_match.isOver) {
          _ticker?.cancel();
          _phase = _SnowPhase.over;
        }
      });
    });
  }

  void _throw(int i) {
    if (_phase != _SnowPhase.playing || !_match.alive(i)) return;
    final hit = _match.throwSnowball(i);
    setState(() {
      _banner = hit
          ? 'لاعب ${i + 1} أصاب قلعة لاعب ${_match.targetOf(i) == i ? i + 1 : _match.targetOf(i) + 1}! ❄'
          : 'لاعب ${i + 1} رمى بعيد 😬';
      if (_match.isOver) {
        _ticker?.cancel();
        _phase = _SnowPhase.over;
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

  Widget _powerBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const tol = SnowBrawlMatch.tolerance;
        return SizedBox(
          height: 30,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: FlatColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: w * (_match.neededPower - tol),
                width: w * tol * 2,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: FlatColors.tilePastels[1],
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

  Widget _fortsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < _match.playerCount; i++)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _match.alive(i)
                      ? _colors[i].withValues(alpha: 0.35)
                      : FlatColors.border,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _match.alive(i) ? _colors[i] : FlatColors.border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    _match.alive(i) ? '🏰' : '💥',
                    style: const TextStyle(fontSize: 22)
                        .copyWith(fontFamilyFallback: _emojiFallback),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'لاعب ${i + 1}: ${_match.hp[i]}',
                style: flatCairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _match.alive(i) ? FlatColors.ink : FlatColors.ink.withValues(alpha: 0.5),
                ).copyWith(fontFamilyFallback: _emojiFallback),
              ),
            ],
          ),
      ],
    );
  }

  Widget _throwButton(int i) {
    final active = _phase == _SnowPhase.playing && _match.alive(i);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _colors[i],
            disabledBackgroundColor: _colors[i].withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: active ? () => _throw(i) : null,
          child: Text(
            'لاعب ${i + 1} ❄',
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
        VictoryFriends(winnerName: 'لاعب ${_match.winner! + 1}'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _phase = _SnowPhase.pickPlayers),
          child: Text(
            'العبوا تاني ❄',
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
        title: 'معركة التلج',
        description:
            '٢-٤ قلاع على نفس الموبايل. عدّاد القوة بيطلع وينزل.. دوس لما يوصل للعلامة الزرقا عشان كورت التلج توصل قلعة خصمك. أول واحد يهد كل القلاع يكسب ❄',
        icon: '❄',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    final players = _phase == _SnowPhase.pickPlayers ? 0 : _match.playerCount;
    return OfflineGameScaffold(
      title: 'معركة التلج',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: _phase == _SnowPhase.pickPlayers
            ? _buildPicker()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: _fortsRow(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: _powerBar(),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    child: _phase == _SnowPhase.over
                        ? Center(child: _buildOver())
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: CustomPaint(
                                  painter: _SnowFieldPainter(
                                    match: _match,
                                    colors: _colors,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                    child: Row(
                      children: [
                        for (var i = 0; i < players; i++) _throwButton(i)
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SnowFieldPainter extends CustomPainter {
  _SnowFieldPainter({required this.match, required this.colors});

  final SnowBrawlMatch match;
  final List<Color> colors;

  static const List<Offset> _forts = [
    Offset(0.14, 0.14),
    Offset(0.86, 0.14),
    Offset(0.86, 0.86),
    Offset(0.14, 0.86),
  ];

  void _fort(Canvas canvas, Offset c, double s, Color col, bool alive) {
    final body = alive ? col : const Color(0xFFB9B3C9);
    final dark = Color.lerp(body, Colors.black, 0.35)!;
    final w = s * 0.9;
    // main tower
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - w / 2, c.dy - w * 0.55, w, w * 0.9),
        Radius.circular(w * 0.08),
      ),
      Paint()..color = body,
    );
    // battlements
    for (var k = -1; k <= 1; k++) {
      canvas.drawRect(
        Rect.fromLTWH(
            c.dx + k * w * 0.36 - w * 0.11, c.dy - w * 0.78, w * 0.22, w * 0.26),
        Paint()..color = body,
      );
    }
    // snow cap
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - w * 0.58, c.dy - w * 0.86, w * 1.16, w * 0.14),
        Radius.circular(w * 0.07),
      ),
      Paint()..color = Colors.white.withValues(alpha: alive ? 0.95 : 0.3),
    );
    // gate
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - w * 0.14, c.dy - w * 0.02, w * 0.28, w * 0.37),
        Radius.circular(w * 0.1),
      ),
      Paint()..color = dark,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    Offset at(double x, double y) => Offset(x * w, y * w);

    // sky
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      Paint()..color = const Color(0xFFCFE6FF),
    );
    // snow ground
    final ground = Path()
      ..moveTo(0, w * 0.62)
      ..quadraticBezierTo(w * 0.25, w * 0.56, w * 0.5, w * 0.62)
      ..quadraticBezierTo(w * 0.75, w * 0.68, w, w * 0.6)
      ..lineTo(w, w)
      ..lineTo(0, w)
      ..close();
    canvas.drawPath(ground, Paint()..color = FlatColors.tileWhite);
    canvas.drawPath(
      ground,
      Paint()
        ..color = FlatColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // falling flakes (position varies with tick for motion)
    final flake = Paint()..color = const Color(0xFF9FB8D8);
    for (var i = 0; i < 22; i++) {
      final fx = ((i * 0.173 + 0.05) % 1.0) * w;
      final fy = (((i * 0.311 + match.tickCount * 0.004) % 1.0)) * w * 0.58;
      canvas.drawCircle(Offset(fx, fy), 1.6 + (i % 3), flake);
    }

    // forts
    for (var p = 0; p < match.playerCount; p++) {
      _fort(canvas, at(_forts[p].dx, _forts[p].dy), w * 0.12, colors[p],
          match.alive(p));
    }

    // aim arcs: each alive player lobs toward their current target
    for (var p = 0; p < match.playerCount; p++) {
      if (!match.alive(p)) continue;
      final t = match.targetOf(p);
      if (t == p) continue;
      final from = at(_forts[p].dx, _forts[p].dy - 0.1);
      final to = at(_forts[t].dx, _forts[t].dy - 0.08);
      final mid = Offset((from.dx + to.dx) / 2,
          min(from.dy, to.dy) - w * 0.16);
      final arc = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy);
      canvas.drawPath(
        arc,
        Paint()
          ..color = colors[p].withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      // snowball riding the arc at the power-meter phase
      final ball = Paint()..color = FlatColors.ink;
      final bx = from.dx + (to.dx - from.dx) * match.phase;
      final t2 = match.phase;
      final by = (1 - t2) * (1 - t2) * from.dy +
          2 * (1 - t2) * t2 * mid.dy +
          t2 * t2 * to.dy;
      canvas.drawCircle(Offset(bx, by), w * 0.018, ball);
      canvas.drawCircle(Offset(bx, by), w * 0.018,
          Paint()
            ..color = const Color(0xFFB8CCe0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_SnowFieldPainter oldDelegate) => true;
}

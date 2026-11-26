import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import '../../services/arcade_juice.dart';
import 'snow_brawl_logic.dart';

/// معركة التلج: 1-4 players (+ optional bots), one throw button each,
/// placed on the player's own side (top buttons rotated face-to-face).
class SnowBrawlGame extends StatefulWidget {
  const SnowBrawlGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<SnowBrawlGame> createState() => _SnowBrawlGameState();
}

enum _SnowPhase { pickPlayers, pickBots, playing, over }

class _SnowBrawlGameState extends State<SnowBrawlGame> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  _SnowPhase _phase = _SnowPhase.pickPlayers;
  late SnowBrawlMatch _match;
  Timer? _ticker;
  String _banner = '';
  int _humans = 2;
  bool _practice = false;

  @visibleForTesting
  SnowBrawlMatch get debugMatch => _match;

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

  void _juiceEnd() {
    final w = _match.winner;
    if (w == null) return;
    (w < _humans) ? ArcadeJuice.win() : ArcadeJuice.lose();
  }

  void _startMatch(int humans, bool withBots) {
    ArcadeJuice.tap();
    _ticker?.cancel();
    _humans = humans;
    _practice = humans == 1 && !withBots;
    final seats = _practice ? 1 : (withBots ? 4 : humans);
    final m = SnowBrawlMatch(
      playerCount: seats,
      random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
    );
    for (var i = humans; i < seats && withBots; i++) {
      m.botSeats.add(i);
    }
    setState(() {
      _match = m;
      _banner = _practice
          ? 'دوس لما عدّاد القوة يوصل للعلامة! ❄'
          : 'دوس لما عدّاد القوة يوصل للعلامة! ❄';
      _phase = _SnowPhase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted || _phase != _SnowPhase.playing) return;
      setState(() {
        _match.tick();
        if (_match.isOver) {
          _ticker?.cancel();
          _phase = _SnowPhase.over;
        _juiceEnd();
          _juiceEnd();
        }
      });
    });
  }

  void _throw(int i) {
    if (_phase != _SnowPhase.playing || i >= _humans || !_match.alive(i)) return;
    final hit = _match.throwSnowball(i);
    setState(() {
      _banner = _practice
          ? (hit ? 'إصابة! ❄' : 'رميت بعيد 😬')
          : hit
              ? '${PlayerNames.name(i)} أصاب قلعة ${PlayerNames.name(_match.targetOf(i) == i ? i : _match.targetOf(i))}! ❄'
              : '${PlayerNames.name(i)} رمى بعيد 😬';
      if (_match.isOver) {
        _ticker?.cancel();
        _phase = _SnowPhase.over;
        _juiceEnd();
      }
    });
  }

  TextStyle _t(double size, {Color? color, FontWeight w = FontWeight.w800}) =>
      flatCairo(fontSize: size, fontWeight: w, color: color ?? FlatColors.ink)
          .copyWith(fontFamilyFallback: _emojiFallback);

  Widget _bigChoice(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: 220,
          child: FilledButton(onPressed: onTap, child: Text(label, style: _t(18, color: Colors.white))),
        ),
      );

  Widget _buildPicker() => Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('كام لاعب؟', style: _t(26)),
            const SizedBox(height: 20),
            _bigChoice('لاعب واحد', () {
              _humans = 1;
              setState(() => _phase = _SnowPhase.pickBots);
            }),
            for (final n in [2, 3, 4])
              _bigChoice('$n لاعبين', () {
                _humans = n;
                if (n == 4) {
                  _startMatch(4, false);
                } else {
                  setState(() => _phase = _SnowPhase.pickBots);
                }
              }),
          ]),
        ),
      );

  Widget _buildBots() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('نضيف بوتات؟', style: _t(26)),
          const SizedBox(height: 8),
          Text(
            _humans == 1
                ? 'من غير بوتات هتتدرب على التصويب: ١٠ رميات على هدف تدريب'
                : 'البوتات بتكمّل لحد ٤ لاعبين',
            style: _t(14, w: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () => _startMatch(_humans, true)),
          _bigChoice('لا', () => _startMatch(_humans, false)),
        ]),
      );

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
                '${_match.botSeats.contains(i) ? 'بوت' : 'لاعب'} ${i + 1}: ${_match.hp[i]}',
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
          key: Key('snow_throw_$i'),
          style: FilledButton.styleFrom(
            backgroundColor: _colors[i],
            disabledBackgroundColor: _colors[i].withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: active ? () => _throw(i) : null,
          child: Text(
            '${PlayerNames.name(i)} ❄',
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
    final w = _match.winner;
    Widget head;
    if (_practice) {
      head = Text('أصبت ${_match.hits[0]} من ${SnowBrawlMatch.practiceThrows} ❄', style: _t(22));
    } else if (w != null && _match.botSeats.contains(w)) {
      head = Text('البوتات كسبوا 🤖', style: _t(22));
    } else if (w != null) {
      head = VictoryFriends(gameTitle: 'معركة التلج', winnerName: '${PlayerNames.name(w)}', winnerSeats: [w]);
    } else {
      head = Text('تعادل! 😅', style: _t(20));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        head,
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
      return OfflineGameScaffold(
        title: 'معركة التلج',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
        title: 'معركة التلج',
            playersLabel: '١-٤ لاعبين',
            showBotsChip: true,
        description:
            '١-٤ قلاع على نفس الموبايل، وتقدر تضيف بوتات. عدّاد القوة بيطلع وينزل.. دوس لما يوصل للعلامة الزرقا عشان كورت التلج توصل قلعة خصمك. أول واحد يهد كل القلاع يكسب ❄',
        icon: '❄',
        onStart: () => setState(() => _showIntro = false),
      ),
      );
    }
    if (_phase == _SnowPhase.pickPlayers || _phase == _SnowPhase.pickBots) {
      return OfflineGameScaffold(
        title: 'معركة التلج',
        backgroundColor: FlatColors.bg,
        body: SafeArea(
          child: _phase == _SnowPhase.pickPlayers ? _buildPicker() : _buildBots(),
        ),
      );
    }
    final humanSeats = [for (var i = 0; i < _humans; i++) i];
    final split = (humanSeats.length / 2).ceil();
    final bottomSeats = humanSeats.take(split).toList();
    final topSeats = humanSeats.skip(split).toList();
    return OfflineGameScaffold(
      title: 'معركة التلج',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: Column(
                children: [
                  if (topSeats.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Transform.rotate(
                        angle: pi,
                        child: Row(children: [
                          for (var i = topSeats.length - 1; i >= 0; i--)
                            _throwButton(topSeats[i]),
                        ]),
                      ),
                    ),
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
                      textDirection: TextDirection.rtl,
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
                    child: Row(children: [for (final i in bottomSeats) _throwButton(i)]),
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

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import '../../services/arcade_juice.dart';
import 'chicken_run_logic.dart';

/// جري الفراخ: one-touch gravity runner for 1-4 on one phone. Each player
/// has one pad in a screen corner: tap to flip gravity to the other floor.
class ChickenRunGame extends StatefulWidget {
  const ChickenRunGame({super.key, this.randomSeed});
  final int? randomSeed;

  @override
  State<ChickenRunGame> createState() => _ChickenRunGameState();
}

enum _Phase { pickPlayers, pickBots, playing, over }

class _ChickenRunGameState extends State<ChickenRunGame> {
  static const _emojiFallback = ['Noto Color Emoji'];
  static const _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];
  // Strip order top to bottom, matching the corners of each pad.
  static const _rowOrder = [1, 3, 2, 0];

  bool _showIntro = true;
  _Phase _phase = _Phase.pickPlayers;
  late ChickenRunMatch _match;
  Timer? _ticker;
  int _humans = 2;
  bool _practice = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

    void _juiceEnd() {
    final w = _match.winner;
    if (w == null) return;
    (w >= _humans) ? ArcadeJuice.lose() : ArcadeJuice.win();
  }

void _start(int humans, bool withBots) {
    ArcadeJuice.tap();
    _ticker?.cancel();
    _humans = humans;
    _practice = humans == 1 && !withBots;
    final seats = _practice ? 1 : (withBots ? 4 : humans);
    final m = ChickenRunMatch(
      seats: seats,
      random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
    );
    for (var s = humans; s < seats; s++) {
      m.botSeats.add(s);
    }
    setState(() {
      _match = m;
      _phase = _Phase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted || _phase != _Phase.playing) return;
      setState(() {
        _match.step(0.033);
        if (_match.over) {
          _ticker?.cancel();
          _phase = _Phase.over;
          _juiceEnd();
        }
      });
    });
  }

  @visibleForTesting
  ChickenRunMatch get debugMatch => _match;

  TextStyle _t(double size, {Color? color, FontWeight w = FontWeight.w800}) =>
      flatCairo(fontSize: size, fontWeight: w, color: color ?? FlatColors.ink)
          .copyWith(fontFamilyFallback: _emojiFallback);

  Widget _bigChoice(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: 220,
          child: FilledButton(
              onPressed: onTap, child: Text(label, style: _t(18, color: Colors.white))),
        ),
      );

  Widget _buildPicker() => Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('كام لاعب؟', style: _t(26)),
            const SizedBox(height: 20),
            _bigChoice('لاعب واحد', () {
              _humans = 1;
              setState(() => _phase = _Phase.pickBots);
            }),
            for (final n in [2, 3, 4])
              _bigChoice('$n لاعبين', () {
                _humans = n;
                if (n == 4) {
                  _start(4, false);
                } else {
                  setState(() => _phase = _Phase.pickBots);
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
                ? 'من غير بوتات هتتدرب لوحدك وتشوف هتفضل كام ثانية'
                : 'البوتات بتكمّل لحد ٤ فراخ',
            style: _t(14, w: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () => _start(_humans, true)),
          _bigChoice('لا', () => _start(_humans, false)),
        ]),
      );

  Alignment _corner(int seat) => const [
        Alignment.bottomLeft,
        Alignment.topRight,
        Alignment.bottomRight,
        Alignment.topLeft,
      ][seat];

  Widget _pad(int seat) {
    final alive = _match.alive[seat];
    return Listener(
      key: ValueKey('pad_$seat'),
      onPointerDown: (_) {
        if (_phase == _Phase.playing) _match.flip(seat);
      },
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _colors[seat].withValues(alpha: alive ? 0.9 : 0.25),
          border: Border.all(color: FlatColors.ink, width: 2.5),
        ),
        child: const CustomPaint(painter: _FlipSymbol()),
      ),
    );
  }

  Widget _buildOver() {
    final w = _match.winner;
    Widget head;
    if (_practice) {
      head = Text(
          'وقعت بعد ${_match.survived[0].toStringAsFixed(1)} ثانية 👏',
          textAlign: TextAlign.center,
          style: _t(20));
    } else if (w == null) {
      head = Text('تعادل! وقعوا مع بعض 😅', style: _t(22));
    } else if (w >= _humans) {
      head = BotsWinLabel(gameTitle: 'جري الفراخ', style: _t(22));
    } else {
      head = VictoryFriends(gameTitle: 'جري الفراخ', winnerName: '${PlayerNames.name(w)}', winnerSeats: [w]);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      head,
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => setState(() => _phase = _Phase.pickPlayers),
        child: Text('العبوا تاني', style: _t(18, color: Colors.white)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: 'جري الفراخ',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
        title: 'جري الفراخ',
            playersLabel: '١-٤ لاعبين',
            showBotsChip: true,
        description:
            'كل واحد فرخته بتجري على أرضية فيها حفر. دوس على زرارك في ركنك عشان تقلب الجاذبية وتنط للأرضية التانية قبل الحفرة. متقدرش تنط وانت في الهوا. آخر فرخة واقفة تكسب',
        icon: '🐔',
        onStart: () => setState(() => _showIntro = false),
      ),
      );
    }
    return OfflineGameScaffold(
      title: 'جري الفراخ',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: switch (_phase) {
          _Phase.pickPlayers => _buildPicker(),
          _Phase.pickBots => _buildBots(),
          _Phase.over => Center(child: _buildOver()),
          _Phase.playing => Padding(
              padding: const EdgeInsets.all(6),
              child: Stack(children: [
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) {
                      // Solo: a tap anywhere flips.
                      if (_humans == 1 && _phase == _Phase.playing) {
                        _match.flip(0);
                      }
                    },
                    child: CustomPaint(
                      painter: _RunPainter(_match, _colors, _rowOrder),
                    ),
                  ),
                ),
                for (var s = 0; s < _humans; s++)
                  Align(
                    alignment: _corner(s),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: _pad(s),
                    ),
                  ),
              ]),
            ),
        },
      ),
    );
  }
}

class _RunPainter extends CustomPainter {
  _RunPainter(this.m, this.colors, this.rowOrder);
  final ChickenRunMatch m;
  final List<Color> colors;
  final List<int> rowOrder;

  @override
  void paint(Canvas canvas, Size size) {
    final rows = [for (final s in rowOrder) if (s < m.seats) s];
    final gap = 6.0;
    final rh = (size.height - gap * (rows.length - 1)) / rows.length;
    for (var r = 0; r < rows.length; r++) {
      final seat = rows[r];
      final rect = Rect.fromLTWH(0, r * (rh + gap), size.width, rh);
      _strip(canvas, rect, seat);
    }
  }

  void _strip(Canvas canvas, Rect rect, int seat) {
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    canvas.drawRRect(rr, Paint()..color = FlatColors.tileWhite);
    canvas.save();
    canvas.clipRRect(rr);
    final w = rect.width;
    final thick = max(6.0, rect.height * 0.07);
    final floorY = rect.bottom - thick;
    final ceilY = rect.top;
    final floorPaint = Paint()..color = colors[seat].withValues(alpha: 0.55);
    // surfaces: draw solid bars, then cut holes (background colored gap).
    canvas.drawRect(Rect.fromLTWH(rect.left, floorY, w, thick), floorPaint);
    canvas.drawRect(Rect.fromLTWH(rect.left, ceilY, w, thick), floorPaint);
    for (final h in m.holes) {
      final x0 = rect.left + (h.start - m.scroll) * w;
      final x1 = rect.left + (h.end - m.scroll) * w;
      if (x1 < rect.left || x0 > rect.right) continue;
      final y = h.surface == 0 ? floorY : ceilY;
      canvas.drawRect(Rect.fromLTRB(x0, y, x1, y + thick), Paint()..color = FlatColors.bg);
    }
    // chicken
    final cx = rect.left + ChickenRunMatch.chickenX * w;
    final r = min(rect.height * 0.14, 22.0);
    final onFloor = m.surface[seat] == 0;
    final restY = onFloor ? floorY - r : ceilY + thick + r;
    final otherY = onFloor ? ceilY + thick + r : floorY - r;
    var y = restY;
    var alive = m.alive[seat];
    if (m.flightLeft[seat] > 0) {
      final t = 1 - m.flightLeft[seat] / ChickenRunMatch.flipTime;
      y = restY + (otherY - restY) * t;
    }
    final dir = (m.flightLeft[seat] > 0 ? !onFloor : onFloor) ? 1.0 : -1.0;
    if (alive) {
      _chicken(canvas, Offset(cx, y), r, dir, colors[seat]);
    }
    // label
    final label = TextPainter(
      text: TextSpan(
        text: alive
            ? '${PlayerNames.name(seat)}'
            : '${PlayerNames.name(seat)} وقع بعد ${m.survived[seat].toStringAsFixed(1)} ث',
        style: flatCairo(fontSize: 12, fontWeight: FontWeight.w800, color: FlatColors.ink),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    label.paint(canvas, Offset(rect.left + (w - label.width) / 2, rect.center.dy - label.height / 2));
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..color = FlatColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _chicken(Canvas c, Offset p, double r, double dir, Color tint) {
    // dir: +1 stands on the floor (up is -y), -1 hangs from the ceiling.
    final up = -dir;
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(1, dir > 0 ? 1 : -1);
    final ink = Paint()
      ..color = FlatColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    // tail
    c.drawCircle(Offset(-r * 0.95, -r * 0.1), r * 0.4, Paint()..color = tint);
    c.drawCircle(Offset(-r * 0.95, -r * 0.1), r * 0.4, ink);
    // body
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.1, height: r * 1.8), Paint()..color = Colors.white);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.1, height: r * 1.8), ink);
    // comb
    c.drawCircle(Offset(r * 0.55, -r * 0.95), r * 0.28, Paint()..color = const Color(0xFFE5483B));
    c.drawCircle(Offset(r * 0.3, -r * 0.9), r * 0.22, Paint()..color = const Color(0xFFE5483B));
    // beak
    final beak = Path()
      ..moveTo(r * 1.0, -r * 0.2)
      ..lineTo(r * 1.45, -r * 0.05)
      ..lineTo(r * 1.0, r * 0.15)
      ..close();
    c.drawPath(beak, Paint()..color = const Color(0xFFFFB02E));
    // eye
    c.drawCircle(Offset(r * 0.55, -r * 0.3), r * 0.12, Paint()..color = FlatColors.ink);
    c.restore();
    // keep `up` referenced for readers: dir handled via scale.
    assert(up.abs() == 1);
  }

  @override
  bool shouldRepaint(covariant _RunPainter old) => true;
}

/// Two opposing arrows drawn as vectors (no icon font needed).
class _FlipSymbol extends CustomPainter {
  const _FlipSymbol();
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final a = size.shortestSide * 0.22;
    // left arrow pointing up, right arrow pointing down
    for (final sgn in [-1.0, 1.0]) {
      final x = c.dx + sgn * a * 0.9;
      final top = c.dy - a * 1.2, bot = c.dy + a * 1.2;
      canvas.drawLine(Offset(x, top), Offset(x, bot), p);
      final tip = sgn < 0 ? top : bot;
      final d = sgn < 0 ? 1.0 : -1.0;
      canvas.drawLine(Offset(x, tip), Offset(x - a * 0.6, tip + d * a * 0.7), p);
      canvas.drawLine(Offset(x, tip), Offset(x + a * 0.6, tip + d * a * 0.7), p);
    }
  }

  @override
  bool shouldRepaint(covariant _FlipSymbol old) => false;
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import '../../services/arcade_juice.dart';
import 'car_race_logic.dart';

/// سباق العربيات: top-down 3-lap race for 1-4 on one phone. Cars drive on
/// their own; each player holds a left or right pad in their screen corner.
class CarRaceGame extends StatefulWidget {
  const CarRaceGame({super.key, this.randomSeed});
  final int? randomSeed;

  @override
  State<CarRaceGame> createState() => _CarRaceGameState();
}

enum _Phase { pickPlayers, pickBots, playing, over }

class _CarRaceGameState extends State<CarRaceGame> {
  static const _emojiFallback = ['Noto Color Emoji'];
  static const _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  bool _showIntro = true;
  _Phase _phase = _Phase.pickPlayers;
  late CarRaceMatch _match;
  Timer? _ticker;
  int _humans = 2;
  bool _practice = false;
  final Map<int, int> _turn = {};
  final Set<String> _padDown = {};

  void _padEvent(int seat, int dir, bool down) {
    final key = '$seat:$dir';
    final other = '$seat:${-dir}';
    if (down) {
      _padDown.add(key);
      _turn[seat] = dir;
      // Reference mechanic: hold both steering pads to spend a full drift
      // charge as a boost.
      if (_padDown.contains(other)) _match.requestBoost(seat);
    } else {
      _padDown.remove(key);
      _turn[seat] = _padDown.contains(other) ? -dir : 0;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _juiceEnd() {
    final w = _match.winner;
    if (w == null) return;
    _match.botSeats.contains(w) ? ArcadeJuice.lose() : ArcadeJuice.win();
  }

  void _start(int humans, bool withBots) {
    ArcadeJuice.tap();
    _ticker?.cancel();
    _humans = humans;
    _practice = humans == 1 && !withBots;
    final seats = _practice ? 1 : (withBots ? 4 : humans);
    final m = CarRaceMatch(
      seats: seats,
      random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
    );
    for (var s = humans; s < seats; s++) {
      m.botSeats.add(s);
    }
    _turn.clear();
    _padDown.clear();
    setState(() {
      _match = m;
      _phase = _Phase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted || _phase != _Phase.playing) return;
      setState(() {
        _match.step(0.033, _turn);
        if (_match.over) {
          _ticker?.cancel();
          _phase = _Phase.over;
          _juiceEnd();
        }
      });
    });
  }

  @visibleForTesting
  CarRaceMatch get debugMatch => _match;

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
                ? 'من غير بوتات هتتدرب لوحدك وتشوف وقتك في ٣ لفات'
                : 'البوتات بتكمّل لحد ٤ عربيات',
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

  Widget _pad(int seat, int dir) {
    return Listener(
      key: ValueKey('pad_${seat}_${dir < 0 ? 'l' : 'r'}'),
      onPointerDown: (_) => _padEvent(seat, dir, true),
      onPointerUp: (_) => _padEvent(seat, dir, false),
      onPointerCancel: (_) => _padEvent(seat, dir, false),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _colors[seat].withValues(alpha: 0.9),
          border: Border.all(color: FlatColors.ink, width: 2.5),
        ),
        child: CustomPaint(painter: _ChevronSymbol(dir)),
      ),
    );
  }

  /// The seat's pad pair wrapped in a drift-charge ring: fills with the
  /// seat color as charge builds, flashes full when a boost is ready.
  Widget _padCluster(int seat) {
    final e = seat < _match.cars.length ? _match.cars[seat].energy : 0.0;
    return SizedBox(
      width: 136,
      height: 66,
      child: CustomPaint(
        painter: _ChargeRing(e, _colors[seat]),
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _pad(seat, -1),
            const SizedBox(width: 6),
            _pad(seat, 1),
          ]),
        ),
      ),
    );
  }

  Widget _buildOver() {
    final w = _match.winner;
    Widget head;
    if (_practice) {
      head = Text(
          'خلصت ٣ لفات في ${_match.cars[0].finishedAt.toStringAsFixed(1)} ثانية 👏',
          textAlign: TextAlign.center,
          style: _t(20));
    } else if (w == null) {
      head = Text('انتهى السباق', style: _t(22));
    } else if (w >= _humans) {
      head = Text('البوتات كسبوا 🤖', style: _t(22));
    } else {
      head = VictoryFriends(gameTitle: 'سباق العربيات', winnerName: '${PlayerNames.name(w)}', winnerSeats: [w]);
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
        title: 'سباق العربيات',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
        title: 'سباق العربيات',
            playersLabel: '١-٤ لاعبين',
            showBotsChip: true,
        description:
            'سباق ٣ لفات على حلبة رملية من فوق. عربيتك بتمشي لوحدها: دوس مطوّلاً على السهم الشمال أو اليمين في ركنك عشان تلفّ. اللف القوي وانت بسرعة بيشحن الانجراف، ودوس السهمين مع بعض عشان تعمل تعزيز ⚡. لو خرجت من المسار العربية بتبطّأ. أول واحد يخلّص ٣ لفات يكسب',
        icon: '🏎',
        onStart: () => setState(() => _showIntro = false),
      ),
      );
    }
    return OfflineGameScaffold(
      title: 'سباق العربيات',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: switch (_phase) {
          _Phase.pickPlayers => _buildPicker(),
          _Phase.pickBots => _buildBots(),
          _Phase.over => Center(child: _buildOver()),
          _Phase.playing => LayoutBuilder(builder: (context, c) {
              final h = c.maxHeight - 8;
              final w = min(c.maxWidth - 8, h / CarRaceMatch.arenaH);
              final ph = w * CarRaceMatch.arenaH;
              return Center(
                child: SizedBox(
                  width: w,
                  height: ph,
                  child: Stack(children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _TrackPainter(_match, _colors)),
                    ),
                    for (var s = 0; s < _humans; s++)
                      Align(
                        alignment: _corner(s),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: _padCluster(s),
                        ),
                      ),
                  ]),
                ),
              );
            }),
        },
      ),
    );
  }
}

class _ChevronSymbol extends CustomPainter {
  _ChevronSymbol(this.dir);
  final int dir;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final s = size.shortestSide * 0.18;
    final d = dir.toDouble();
    final path = Path()
      ..moveTo(c.dx - d * s * 0.6, c.dy - s * 1.3)
      ..lineTo(c.dx + d * s * 0.7, c.dy)
      ..lineTo(c.dx - d * s * 0.6, c.dy + s * 1.3);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _ChevronSymbol old) => false;
}

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.m, this.colors);
  final CarRaceMatch m;
  final List<Color> colors;

  static const int _samples = 240;
  List<Point<double>>? _center;

  List<Point<double>> _centerline() {
    if (_center != null) return _center!;
    final pts = <Point<double>>[];
    for (var i = 0; i < _samples; i++) {
      final th = i * 2 * pi / _samples;
      pts.add(CarRaceMatch.centerlinePoint(th));
    }
    _center = pts;
    return pts;
  }

  Path _loop(List<Point<double>> center, double offset, double k) {
    final path = Path();
    for (var i = 0; i <= center.length; i++) {
      final p0 = center[i % center.length];
      // approximate normal: radial from the arena centre
      final nx = p0.x - CarRaceMatch.cx, ny = p0.y - CarRaceMatch.cy;
      final nl = sqrt(nx * nx + ny * ny);
      final x = (p0.x + nx / nl * offset) * k;
      final y = (p0.y + ny / nl * offset) * k;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width;
    final center = _centerline();
    final outer = _loop(center, CarRaceMatch.band, k);
    final inner = _loop(center, -CarRaceMatch.band, k);
    final mid = _loop(center, 0, k);

    // full-bleed sand
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE9D6A7));

    // infield island (lighter sand)
    canvas.drawPath(inner, Paint()..color = const Color(0xFFF2E3BB));

    // packed-dirt track ring
    final ring = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(ring, Paint()..color = const Color(0xFFC9A06C));

    // curbs: alternating red/white blocks along both edges at the corners
    final curbPaint = Paint()..style = PaintingStyle.fill;
    const cornerCenters = [pi / 4, 3 * pi / 4, 5 * pi / 4, 7 * pi / 4];
    const span = 0.34; // radians of corner covered by curbs
    const segStep = 2 * pi / _samples;
    for (final cc in cornerCenters) {
      var segIndex = 0;
      for (var th = cc - span; th < cc + span; th += segStep * 2) {
        final i0 = ((th / (2 * pi)) * _samples).floor() % _samples;
        final i1 = (i0 + 1) % _samples;
        final i2 = (i0 + 2) % _samples;
        for (final off in [CarRaceMatch.band, -CarRaceMatch.band]) {
          final a = center[i0], b = center[i2];
          Offset pt(Point<double> p) {
            final nx = p.x - CarRaceMatch.cx, ny = p.y - CarRaceMatch.cy;
            final nl = sqrt(nx * nx + ny * ny);
            final ob = off - (off > 0 ? -0.012 : -0.012);
            return Offset((p.x + nx / nl * ob) * k, (p.y + ny / nl * ob) * k);
          }

          final pa = pt(a), pb = pt(b);
          final mx = (pa.dx + pb.dx) / 2, my = (pa.dy + pb.dy) / 2;
          final dx = pb.dx - pa.dx, dy = pb.dy - pa.dy;
          final len = sqrt(dx * dx + dy * dy);
          final ux = -dy / len, uy = dx / len;
          const curbW = 5.0;
          final quad = Path()
            ..moveTo(pa.dx + ux * curbW, pa.dy + uy * curbW)
            ..lineTo(pb.dx + ux * curbW, pb.dy + uy * curbW)
            ..lineTo(pb.dx - ux * curbW, pb.dy - uy * curbW)
            ..lineTo(pa.dx - ux * curbW, pa.dy - uy * curbW)
            ..close();
          curbPaint.color = segIndex.isEven
              ? const Color(0xFFEF3437)
              : Colors.white;
          canvas.drawPath(quad, curbPaint);
        }
        segIndex++;
      }
    }

    // white edge lines
    canvas.drawPath(
        outer,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    canvas.drawPath(
        inner,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);

    // dashed centre line
    for (final mt in mid.computeMetrics()) {
      var d = 0.0;
      while (d < mt.length) {
        canvas.drawPath(
            mt.extractPath(d, d + 9),
            Paint()
              ..color = Colors.white70
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        d += 20;
      }
    }

    // start / finish: checkered strip across the dirt at angle 0
    final p0 = CarRaceMatch.centerlinePoint(0);
    final n0x = p0.x - CarRaceMatch.cx, n0y = p0.y - CarRaceMatch.cy;
    final nl = sqrt(n0x * n0x + n0y * n0y);
    final ux = n0x / nl, uy = n0y / nl; // across the track
    const rows = 2, cols = 8;
    final stripW = 0.016, stripL = CarRaceMatch.band - 0.006;
    for (var r = 0; r < rows; r++) {
      for (var cc = 0; cc < cols; cc++) {
        final along = (cc - cols / 2) * stripL * 2 / cols;
        final off = (r - rows / 2) * stripW;
        final px = p0.x + ux * (off + stripW / 2) + uy * along;
        final py = p0.y + uy * (off + stripW / 2) - ux * along;
        // build a small rotated rect
        final rect = Rect.fromCenter(
            center: Offset(px * k, py * k),
            width: stripL * 2 / cols * k,
            height: stripW * k);
        canvas.save();
        canvas.translate(px * k, py * k);
        canvas.rotate(atan2(uy, ux));
        canvas.translate(-px * k, -py * k);
        canvas.drawRect(
            rect,
            Paint()
              ..color = (r + cc).isEven ? FlatColors.ink : Colors.white);
        canvas.restore();
      }
    }

    // drift tire marks
    final markPaint = Paint()
      ..color = const Color(0x55000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < m.cars.length; i++) {
      final trail = m.cars[i].driftTrail;
      if (trail.length < 2) continue;
      final path = Path()..moveTo(trail.first.x * k, trail.first.y * k);
      for (final pt in trail.skip(1)) {
        path.lineTo(pt.x * k, pt.y * k);
      }
      canvas.drawPath(path, markPaint);
    }

    // cars: proper little rally cars (body, wheels, cockpit, wing)
    for (var i = 0; i < m.cars.length; i++) {
      final c = m.cars[i];
      canvas.save();
      canvas.translate(c.x * k, c.y * k);
      canvas.rotate(c.heading - c.slip * 0.4);
      const L = 46.0, W = 24.0;
      // shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: const Offset(2, 3), width: L, height: W),
            const Radius.circular(7)),
        Paint()..color = Colors.black.withValues(alpha: 0.18),
      );
      // wheels
      final wheel = Paint()..color = const Color(0xFF2B2B30);
      for (final wx in [-L * 0.30, L * 0.30]) {
        for (final wy in [-W / 2, W / 2 - 5]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(wx - 6, wy, 12, 5), const Radius.circular(2)),
            wheel,
          );
        }
      }
      // body
      final body = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: L, height: W),
          const Radius.circular(8));
      canvas.drawRRect(body, Paint()..color = colors[i]);
      canvas.drawRRect(
          body,
          Paint()
            ..color = FlatColors.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2);
      // cockpit
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-2, -7, 13, 14), const Radius.circular(4)),
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
      // rear wing
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-L / 2 - 1, -9, 5, 18), const Radius.circular(2)),
        Paint()..color = FlatColors.ink,
      );
      // boost flame
      if (m.boosting(i)) {
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(-L / 2 - 8, 0), width: 16, height: 9),
          Paint()..color = const Color(0xFFFFC93C),
        );
      }
      canvas.restore();
    }

    // HUD in the infield: lap + drift charge per seat
    for (var i = 0; i < m.cars.length; i++) {
      final lap = min(m.laps, m.lapOf(i) + 1);
      final tp = TextPainter(
        text: TextSpan(
          text: '${PlayerNames.name(i)}: لفة $lap/${m.laps}',
          style: flatCairo(
              fontSize: 15, fontWeight: FontWeight.w900, color: FlatColors.ink),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      final ty = size.height / 2 - 56 + i * 30;
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, ty));
    }
  }

  @override
  bool shouldRepaint(covariant _TrackPainter old) => true;
}

/// Thin ring behind a seat's pads showing the drift charge 0..1.
class _ChargeRing extends CustomPainter {
  const _ChargeRing(this.energy, this.color);

  final double energy;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(1.5), const Radius.circular(33)),
        track);
    if (energy <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..addRRect(
          RRect.fromRectAndRadius(rect.deflate(1.5), const Radius.circular(33)));
    for (final mt in path.computeMetrics()) {
      canvas.drawPath(mt.extractPath(0, mt.length * energy), paint);
    }
  }

  @override
  bool shouldRepaint(_ChargeRing old) =>
      old.energy != energy || old.color != color;
}

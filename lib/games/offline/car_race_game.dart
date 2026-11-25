import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
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

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start(int humans, bool withBots) {
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
      onPointerDown: (_) => _turn[seat] = dir,
      onPointerUp: (_) => _turn[seat] = 0,
      onPointerCancel: (_) => _turn[seat] = 0,
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
      head = VictoryFriends(gameTitle: 'سباق العربيات', winnerName: 'لاعب ${w + 1}');
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
      return GameIntroWidget(
        title: 'سباق العربيات',
        description:
            'سباق ٣ لفات على حلبة من فوق. عربيتك بتمشي لوحدها: دوس مطوّلاً على السهم الشمال أو اليمين في ركنك عشان تلفّ. لو خرجت من الأسفلت العربية بتبطّأ. أول واحد يخلّص ٣ لفات يكسب',
        icon: '🏎',
        onStart: () => setState(() => _showIntro = false),
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
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            _pad(s, -1),
                            const SizedBox(width: 6),
                            _pad(s, 1),
                          ]),
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

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width;
    final rr = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFB9E3A8)); // grass
    canvas.save();
    canvas.clipRRect(rr);
    Path ring(double r) {
      return Path()
        ..addOval(Rect.fromCenter(
          center: Offset(CarRaceMatch.cx * k, CarRaceMatch.cy * k),
          width: 2 * CarRaceMatch.a * r * k,
          height: 2 * CarRaceMatch.b * r * k,
        ));
    }
    final outer = ring(1 + CarRaceMatch.band);
    final inner = ring(1 - CarRaceMatch.band);
    final asphalt = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(asphalt, Paint()..color = const Color(0xFF8E94A6));
    canvas.drawPath(outer, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawPath(inner, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
    // inner island
    canvas.drawPath(inner, Paint()..color = const Color(0xFF9ED68B));
    // dashed centre line
    final center = ring(1);
    for (final mt in center.computeMetrics()) {
      var d = 0.0;
      while (d < mt.length) {
        canvas.drawPath(mt.extractPath(d, d + 8),
            Paint()..color = Colors.white70..style = PaintingStyle.stroke..strokeWidth = 2);
        d += 18;
      }
    }
    // start / finish line across the asphalt on the right side
    final sy = CarRaceMatch.cy * k;
    final xIn = (CarRaceMatch.cx + CarRaceMatch.a * (1 - CarRaceMatch.band)) * k;
    final xOut = (CarRaceMatch.cx + CarRaceMatch.a * (1 + CarRaceMatch.band)) * k;
    final seg = (xOut - xIn) / 8;
    for (var i = 0; i < 8; i++) {
      canvas.drawRect(
        Rect.fromLTWH(xIn + i * seg, sy - 3, seg, 6),
        Paint()..color = i.isEven ? FlatColors.ink : Colors.white,
      );
    }
    // cars
    for (var i = 0; i < m.cars.length; i++) {
      final c = m.cars[i];
      canvas.save();
      canvas.translate(c.x * k, c.y * k);
      canvas.rotate(c.heading);
      final body = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 30, height: 18), const Radius.circular(6));
      canvas.drawRRect(body, Paint()..color = colors[i]);
      canvas.drawRRect(body, Paint()..color = FlatColors.ink..style = PaintingStyle.stroke..strokeWidth = 2.2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(1, -6, 9, 12), const Radius.circular(3)),
        Paint()..color = Colors.white,
      );
      canvas.restore();
    }
    // lap counters in the arena centre, one per seat
    for (var i = 0; i < m.cars.length; i++) {
      final lap = min(m.laps, m.lapOf(i) + 1);
      final tp = TextPainter(
        text: TextSpan(
          text: 'لاعب ${i + 1}: لفة $lap/${m.laps}',
          style: flatCairo(fontSize: 15, fontWeight: FontWeight.w900, color: FlatColors.ink),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - 40 + i * 22));
    }
    canvas.restore();
    canvas.drawRRect(rr, Paint()..color = FlatColors.border..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant _TrackPainter old) => true;
}

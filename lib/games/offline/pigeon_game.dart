import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import 'pigeon_logic.dart';

/// أطعم الحمامة: 1-4 players, one slingshot pad per corner. The aim swings
/// by itself; tap to fire a breadcrumb at the wandering pigeon's mouth.
class PigeonGame extends StatefulWidget {
  const PigeonGame({super.key, this.randomSeed});
  final int? randomSeed;

  @override
  State<PigeonGame> createState() => _PigeonGameState();
}

enum _Phase { pickPlayers, pickBots, playing, over }

class _PigeonGameState extends State<PigeonGame> {
  static const _emojiFallback = ['Noto Color Emoji'];
  static const _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  bool _showIntro = true;
  _Phase _phase = _Phase.pickPlayers;
  late PigeonMatch _match;
  Timer? _ticker;
  int _humans = 2;
  bool _practice = false;

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
    final m = PigeonMatch(
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
        }
      });
    });
  }

  @visibleForTesting
  PigeonMatch get debugMatch => _match;

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
                ? 'من غير بوتات هتتدرب لوحدك وتشوف أطعمت كام مرة'
                : 'البوتات بتكمّل لحد ٤ رماة',
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
    final empty = _match.left[seat] == 0;
    return Listener(
      key: ValueKey('pad_$seat'),
      onPointerDown: (_) {
        if (_phase == _Phase.playing) _match.fire(seat);
      },
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _colors[seat].withValues(alpha: empty ? 0.25 : 0.9),
          border: Border.all(color: FlatColors.ink, width: 2.5),
        ),
        alignment: Alignment.center,
        child: Text('${_match.left[seat]}', style: _t(22, color: Colors.white)),
      ),
    );
  }

  Widget _buildOver() {
    final w = _match.winner;
    Widget head;
    if (_practice) {
      head = Text('أطعمت الحمامة ${_match.fed[0]} من ${_match.shots} 👏',
          textAlign: TextAlign.center, style: _t(20));
    } else if (w == null) {
      head = Text('تعادل! الحمامة شبعت منكم كلكم', textAlign: TextAlign.center, style: _t(22));
    } else if (w >= _humans) {
      head = Text('البوتات كسبوا 🤖', style: _t(22));
    } else {
      head = VictoryFriends(gameTitle: 'أطعم الحمامة', winnerName: 'لاعب ${w + 1}');
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
        title: 'أطعم الحمامة',
        description:
            'حمامة جعانة بتتمشى في نص الشاشة. كل واحد معاه مقلاع في ركنه وتصويبه بيتحرك يمين وشمال لوحده. دوس على زرارك لما التصويب يبقى على بقّها عشان تطعمها فتافيت العيش. كل واحد معاه ٨ فتافيت، واللي يطعم أكتر يكسب',
        icon: '🐦',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    return OfflineGameScaffold(
      title: 'أطعم الحمامة',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: switch (_phase) {
          _Phase.pickPlayers => _buildPicker(),
          _Phase.pickBots => _buildBots(),
          _Phase.over => Center(child: _buildOver()),
          _Phase.playing => LayoutBuilder(builder: (context, c) {
              final h = c.maxHeight - 8;
              final w = min(c.maxWidth - 8, h / PigeonMatch.arenaH);
              final ph = w * PigeonMatch.arenaH;
              return Center(
                child: SizedBox(
                  width: w,
                  height: ph,
                  child: Stack(children: [
                    Positioned.fill(child: CustomPaint(painter: _PigeonPainter(_match, _colors, _humans))),
                    for (var s = 0; s < _humans; s++)
                      Align(
                        alignment: _corner(s),
                        child: Padding(padding: const EdgeInsets.all(5), child: _pad(s)),
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

class _PigeonPainter extends CustomPainter {
  _PigeonPainter(this.m, this.colors, this.humans);
  final PigeonMatch m;
  final List<Color> colors;
  final int humans;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width;
    final rr = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18));
    canvas.drawRRect(rr, Paint()..color = FlatColors.tileWhite);
    canvas.save();
    canvas.clipRRect(rr);
    // aim lines (dashed) and crumbs
    for (var i = 0; i < m.seats; i++) {
      final l = PigeonMatch.launchers[i];
      final a = m.aim(i);
      final from = Offset(l[0] * k, l[1] * k);
      for (var d = 30.0; d < 150; d += 16) {
        final p = from + Offset(cos(a), sin(a)) * d;
        canvas.drawCircle(p, 2.6, Paint()..color = colors[i].withValues(alpha: 0.9));
      }
    }
    for (final c in m.crumbs) {
      canvas.drawCircle(Offset(c.x * k, c.y * k), 6, Paint()..color = const Color(0xFFD9A15B));
      canvas.drawCircle(Offset(c.x * k, c.y * k), 6,
          Paint()..color = FlatColors.ink..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    // pigeon
    final p = m.pigeon;
    final pc = Offset(p.x * k, p.y * k);
    final ink = Paint()..color = FlatColors.ink..style = PaintingStyle.stroke..strokeWidth = 2.5;
    canvas.drawOval(Rect.fromCenter(center: pc + const Offset(-22, 10), width: 70, height: 46), Paint()..color = const Color(0xFF9AA3B8));
    canvas.drawOval(Rect.fromCenter(center: pc + const Offset(-22, 10), width: 70, height: 46), ink);
    canvas.drawCircle(pc, 28, Paint()..color = const Color(0xFFB7BFD1));
    canvas.drawCircle(pc, 28, ink);
    // open mouth (the target)
    final open = m.gulpFlash > 0 ? 0.35 : 1.0;
    canvas.drawOval(Rect.fromCenter(center: pc + const Offset(0, 4), width: 36 * open + 8, height: 24 * open + 6),
        Paint()..color = const Color(0xFFE5483B));
    canvas.drawOval(Rect.fromCenter(center: pc + const Offset(0, 4), width: 36 * open + 8, height: 24 * open + 6), ink);
    canvas.drawCircle(pc + const Offset(-12, -14), 4, Paint()..color = FlatColors.ink);
    canvas.drawCircle(pc + const Offset(12, -14), 4, Paint()..color = FlatColors.ink);
    // score pills in the middle of each side
    for (var i = 0; i < m.seats; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'لاعب ${i + 1}: ${m.fed[i]}',
          style: flatCairo(fontSize: 14, fontWeight: FontWeight.w900, color: FlatColors.ink),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      final lx = PigeonMatch.launchers[i][0] * k;
      final ly = PigeonMatch.launchers[i][1] * k;
      final dx = lx < k / 2 ? 80.0 : size.width - 80 - tp.width;
      final dy = ly < size.height / 2 ? 10.0 : size.height - 28.0;
      tp.paint(canvas, Offset(dx, dy));
    }
    canvas.restore();
    canvas.drawRRect(rr, Paint()..color = FlatColors.border..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant _PigeonPainter old) => true;
}

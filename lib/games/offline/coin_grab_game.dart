import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import 'coin_grab_logic.dart';

/// لمّ الفلوس: 1-4 players, one claw pad per corner. The claw sweeps and
/// stretches by itself; tap when its tip is on a coin.
class CoinGrabGame extends StatefulWidget {
  const CoinGrabGame({super.key, this.randomSeed});
  final int? randomSeed;

  @override
  State<CoinGrabGame> createState() => _CoinGrabGameState();
}

enum _Phase { pickPlayers, pickBots, playing, over }

class _CoinGrabGameState extends State<CoinGrabGame> {
  static const _emojiFallback = ['Noto Color Emoji'];
  static const _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  bool _showIntro = true;
  _Phase _phase = _Phase.pickPlayers;
  late CoinGrabMatch _match;
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
    final m = CoinGrabMatch(
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
  CoinGrabMatch get debugMatch => _match;

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
                ? 'من غير بوتات هتتدرب لوحدك وتشوف هتلمّ كام جنيه في دقيقة'
                : 'البوتات بتكمّل لحد ٤ لاعبين',
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
    final cd = _match.cooldown[seat] > 0;
    return Listener(
      key: ValueKey('pad_$seat'),
      onPointerDown: (_) {
        if (_phase == _Phase.playing) _match.grab(seat);
      },
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _colors[seat].withValues(alpha: cd ? 0.45 : 0.95),
          border: Border.all(color: FlatColors.ink, width: 2.5),
        ),
        alignment: Alignment.center,
        child: Text('${_match.scores[seat]}', style: _t(22, color: Colors.white)),
      ),
    );
  }

  Widget _buildOver() {
    final w = _match.winner;
    Widget head;
    if (_practice) {
      head = Text('لمّيت ${_match.scores[0]} جنيه (${_match.grabbed[0]} عملة) 👏',
          textAlign: TextAlign.center, style: _t(20));
    } else if (w == null) {
      head = Text('تعادل! الكل لمّ نفس الفلوس', textAlign: TextAlign.center, style: _t(22));
    } else if (w >= _humans) {
      head = Text('البوتات كسبوا 🤖', style: _t(22));
    } else {
      head = VictoryFriends(gameTitle: 'لمّ الفلوس', winnerName: 'لاعب ${w + 1}');
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
        title: 'لمّ الفلوس',
        description:
            'كل واحد معاه كلّاب في ركنه بيتحرك ويمدّ لوحده في الأرضية. دوس على زرارك لما طرف الكلّاب يبقى فوق عملة عشان تلمّها. الدهبية بعشرة والفضية بخمسة. معاكم دقيقة، أغنى واحد يكسب',
        icon: '🪙',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    return OfflineGameScaffold(
      title: 'لمّ الفلوس',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: switch (_phase) {
          _Phase.pickPlayers => _buildPicker(),
          _Phase.pickBots => _buildBots(),
          _Phase.over => Center(child: _buildOver()),
          _Phase.playing => LayoutBuilder(builder: (context, c) {
              final h = c.maxHeight - 8;
              final w = min(c.maxWidth - 8, h / CoinGrabMatch.arenaH);
              final ph = w * CoinGrabMatch.arenaH;
              return Center(
                child: SizedBox(
                  width: w,
                  height: ph,
                  child: Stack(children: [
                    Positioned.fill(child: CustomPaint(painter: _CoinPainter(_match, _colors, _humans))),
                    for (var s = 0; s < _match.seats; s++)
                      Align(
                        alignment: _corner(s),
                        child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: s < _humans ? _pad(s) : IgnorePointer(child: Opacity(opacity: 0.6, child: _pad(s))),
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

class _CoinPainter extends CustomPainter {
  _CoinPainter(this.m, this.colors, this.humans);
  final CoinGrabMatch m;
  final List<Color> colors;
  final int humans;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width;
    final rr = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18));
    canvas.drawRRect(rr, Paint()..color = FlatColors.tileWhite);
    canvas.save();
    canvas.clipRRect(rr);
    // coins
    for (final c in m.coins) {
      final (fill, rim, r) = switch (c.value) {
        10 => (const Color(0xFFFFD64A), const Color(0xFFB8860B), 14.0),
        5 => (const Color(0xFFC0C8D8), const Color(0xFF7A8494), 12.0),
        _ => (const Color(0xFFE8A05C), const Color(0xFF9C6633), 10.0),
      };
      final o = Offset(c.x * k, c.y * k);
      canvas.drawCircle(o, r, Paint()..color = rim);
      canvas.drawCircle(o, r - 2.5, Paint()..color = fill);
    }
    // claws
    for (var i = 0; i < m.seats; i++) {
      final b = CoinGrabMatch.bases[i];
      final from = Offset(b[0] * k, b[1] * k);
      final t = m.tip(i);
      final to = Offset(t.x * k, t.y * k);
      canvas.drawLine(from, to, Paint()..color = colors[i]..strokeWidth = 4..strokeCap = StrokeCap.round);
      canvas.drawCircle(to, CoinGrabMatch.reach * k, Paint()..color = colors[i].withValues(alpha: 0.22));
      canvas.drawCircle(to, CoinGrabMatch.reach * k, Paint()..color = colors[i]..style = PaintingStyle.stroke..strokeWidth = 2.5);
      canvas.drawCircle(to, 5, Paint()..color = FlatColors.ink);
    }
    final lg = m.lastGrab;
    if (lg != null) {
      final tp = TextPainter(
        text: TextSpan(text: '+${lg.value}', style: flatCairo(fontSize: 20, fontWeight: FontWeight.w900, color: colors[lg.seat])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lg.x * k - tp.width / 2, lg.y * k - 30 - (0.6 - lg.ttl) * 30));
    }
    // clock
    final clk = TextPainter(
      text: TextSpan(text: '${m.timeLeft.ceil()}', style: flatCairo(fontSize: 22, fontWeight: FontWeight.w900, color: FlatColors.ink)),
      textDirection: TextDirection.ltr,
    )..layout();
    clk.paint(canvas, Offset((size.width - clk.width) / 2, 8));
    canvas.restore();
    canvas.drawRRect(rr, Paint()..color = FlatColors.border..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant _CoinPainter old) => true;
}

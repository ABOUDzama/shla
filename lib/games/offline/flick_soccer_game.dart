import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import 'flick_soccer_logic.dart';

/// فليك الشلة: faithful clone of the reference's "Flick Soccer" - pull back
/// your star disc, let go, flick the ball into the other goal. First to 3.
/// Original code and flat art.
class FlickSoccerGame extends StatefulWidget {
  const FlickSoccerGame({super.key, this.randomSeed});

  final int? randomSeed;

  @override
  State<FlickSoccerGame> createState() => _FlickSoccerGameState();
}

enum _Phase { pickPlayers, pickBots, playing, over }

class _FlickSoccerGameState extends State<FlickSoccerGame> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  _Phase _phase = _Phase.pickPlayers;
  int _humans = 2;
  late FlickSoccerMatch _match;
  Timer? _ticker;
  Timer? _botTimer;
  Offset? _pullStart; // field coords of drag start
  Offset _pull = Offset.zero; // current drag vector (field units)
  bool _dragging = false;

  static const List<Color> _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFFFFC93C),
    Color(0xFF35C99E),
  ];

  TextStyle _t(double size,
          {FontWeight w = FontWeight.w800, Color color = FlatColors.ink}) =>
      flatCairo(fontSize: size, fontWeight: w, color: color)
          .copyWith(fontFamilyFallback: _emojiFallback);

  @visibleForTesting
  FlickSoccerMatch get debugMatch => _match;

  @override
  void dispose() {
    _ticker?.cancel();
    _botTimer?.cancel();
    super.dispose();
  }

  void _startGame(int humans, bool withBots) {
    _ticker?.cancel();
    _botTimer?.cancel();
    _humans = humans;
    final practice = humans == 1 && !withBots;
    final seats = practice ? 1 : (withBots ? 4 : humans);
    final bots = <int>{for (var i = humans; i < seats; i++) i};
    setState(() {
      _match = FlickSoccerMatch(
        seats: seats,
        random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
      )..botSeats.addAll(bots);
      _phase = _Phase.playing;
      _dragging = false;
    });
    var acc = 0.0;
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      setState(() {
        // 120 Hz physics from a ~60 Hz frame timer
        acc += 2;
        while (acc >= 1) {
          _match.step();
          acc -= 1;
        }
        if (_match.over) {
          _ticker?.cancel();
          _phase = _Phase.over;
        }
      });
      _maybeBotFlick();
    });
  }

  void _maybeBotFlick() {
    if (_phase != _Phase.playing || _match.over) return;
    final s = _match.currentSeat;
    if (!_match.botSeats.contains(s) || !_match.settled) return;
    _botTimer ??= Timer(const Duration(milliseconds: 700), () {
      _botTimer = null;
      if (!mounted || _match.over) return;
      final aim = _match.botAim(s);
      setState(() => _match.flick(s, aim[0], aim[1]));
    });
  }

  // ------------------------------------------------------------ pickers ---

  Widget _bigChoice(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: 220,
          child: FilledButton(
              onPressed: onTap,
              child: Text(label, style: _t(18, color: Colors.white))),
        ),
      );

  Widget _pickPlayers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('كام لاعب؟ ⚽', style: _t(22, w: FontWeight.w900)),
          const SizedBox(height: 20),
          _bigChoice('لاعب واحد', () {
            _humans = 1;
            setState(() => _phase = _Phase.pickBots);
          }),
          for (var n = 2; n <= 4; n++)
            _bigChoice('$n لاعبين', () {
              _humans = n;
              if (n == 4) {
                _startGame(4, false);
              } else {
                setState(() => _phase = _Phase.pickBots);
              }
            }),
        ],
      ),
    );
  }

  Widget _pickBots() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('نضيف بوتات؟ 🤖', style: _t(20, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            _humans == 1
                ? 'لوحدك: ١٠ فليكات تسدد بيهم على الجون'
                : 'الأماكن الفاضية تتملى بوتات',
            style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () => _startGame(_humans, true)),
          _bigChoice('لا', () => _startGame(_humans, false)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- game ---

  Offset _toField(Offset local, double scale) => Offset(local.dx / scale, local.dy / scale);

  void _onPanStart(DragStartDetails d, double scale) {
    if (_phase != _Phase.playing || _match.over || !_match.settled) return;
    final seat = _match.currentSeat;
    if (_match.botSeats.contains(seat)) return;
    final p = _toField(d.localPosition, scale);
    final disc = _match.discs[seat];
    final dist = (p - Offset(disc.x, disc.y)).distance;
    if (dist > FlickSoccerMatch.discR * 2.2) return; // must grab near your disc
    setState(() {
      _dragging = true;
      _pullStart = p;
      _pull = Offset.zero;
    });
  }

  void _onPanUpdate(DragUpdateDetails d, double scale) {
    if (!_dragging) return;
    setState(() => _pull += d.delta / scale);
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_dragging) return;
    final pull = _pull;
    setState(() {
      _dragging = false;
      _pull = Offset.zero;
    });
    _match.flick(_match.currentSeat, pull.dx, pull.dy);
  }

  Widget _scoreChip(int seat) {
    final color = _colors[seat];
    final isTurn = _phase == _Phase.playing && _match.currentSeat == seat;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTurn ? color.withValues(alpha: 0.25) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: isTurn ? 2.5 : 1.2),
      ),
      child: Text(
        '${_match.botSeats.contains(seat) ? '🤖 ' : ''}${PlayerNames.name(seat)} ${_match.practice ? '🥅${_match.practiceGoals}' : '⚽${_match.scores[seat]}'}',
        textDirection: TextDirection.rtl,
        style: _t(11, w: FontWeight.w900),
      ),
    );
  }

  Widget _playing() {
    return Column(
      children: [
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          children: [for (var s = 0; s < _match.seats; s++) _scoreChip(s)],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(builder: (context, bc) {
                final scale = bc.maxWidth / FlickSoccerMatch.fieldW;
                return GestureDetector(
                  key: const ValueKey('flick_field'),
                  onPanStart: (d) => _onPanStart(d, scale),
                  onPanUpdate: (d) => _onPanUpdate(d, scale),
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    painter: _PitchPainter(_match, _colors, _dragging, _pull),
                    size: Size.square(bc.maxWidth),
                  ),
                );
              }),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Text(
            _match.practice
                ? 'اسحب القرص ورا وسيبه عشان تسدد 🥅 (${_match.flicksUsed}/${FlickSoccerMatch.practiceFlicks})'
                : _match.botSeats.contains(_match.currentSeat)
                    ? 'دور ${_match.botSeats.contains(_match.currentSeat) ? '🤖 ' : ''}${PlayerNames.name(_match.currentSeat)}'
                    : 'دورك: اسحب القرص بتاعك ورا وسيبه ⚽',
            textDirection: TextDirection.rtl,
            style: _t(13, w: FontWeight.w900,
                color: FlatColors.ink.withValues(alpha: 0.7)),
          ),
        ),
      ],
    );
  }

  Widget _buildOver() {
    final w = _match.winner;
    Widget head;
    if (_match.practice) {
      head = Text(
          'سجّلت ${_match.practiceGoals} جون من ${FlickSoccerMatch.practiceFlicks} فليكات 🥅',
          textAlign: TextAlign.center,
          style: _t(20));
    } else if (w == null) {
      head = Text('انتهى الماتش', style: _t(22));
    } else if (_match.botSeats.contains(w)) {
      head = Text('البوتات كسبوا 🤖', style: _t(22));
    } else {
      head = VictoryFriends(
          gameTitle: 'فليك الشلة',
          winnerName: PlayerNames.name(w),
          winnerSeats: [w]);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      head,
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => setState(() => _phase = _Phase.pickPlayers),
        child: Text('العبوا تاني ⚽', style: _t(18, color: Colors.white)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: 'فليك الشلة',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
          title: 'فليك الشلة',
          playersLabel: '١-٤ لاعبين',
          showBotsChip: true,
          description:
              'كورة بالأزارير! اسحب قرصك النجمة ورا وسيبه عشان يتفلّك ناحية الكورة. أول واحد يسجّل ٣ جوون يكسب. خد بالك من حارس المرمى 🧤',
          icon: '⚽',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }
    return OfflineGameScaffold(
      title: 'فليك الشلة',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: switch (_phase) {
          _Phase.pickPlayers => _pickPlayers(),
          _Phase.pickBots => _pickBots(),
          _Phase.over => Center(child: _buildOver()),
          _Phase.playing => _playing(),
        },
      ),
    );
  }
}

/// Top-down pitch: mowed stripes, white lines, goal boxes, star discs, ball.
class _PitchPainter extends CustomPainter {
  _PitchPainter(this.m, this.colors, this.dragging, this.pull);

  final FlickSoccerMatch m;
  final List<Color> colors;
  final bool dragging;
  final Offset pull;

  static const double W = FlickSoccerMatch.fieldW;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / W;
    Offset P(double x, double y) => Offset(x * s, y * s);

    // pitch with mowed stripes
    for (var i = 0; i < 8; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * 12.5 * s, size.width, 12.5 * s),
        Paint()
          ..color = i.isEven ? const Color(0xFF58A34C) : const Color(0xFF4E9643),
      );
    }
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * s;
    // halfway line + center circle
    canvas.drawLine(P(0, 50), P(100, 50), line);
    canvas.drawCircle(P(50, 50), 14 * s, line);
    // goals: white boxes at the edges
    for (final g in m.goals) {
      final ownerColor = g.owner >= 0 ? colors[g.owner] : Colors.white;
      final mouth = Rect.fromCenter(
          center: P(g.cx, g.cy),
          width: (g.ny != 0 ? g.halfWidth * 2 : 6) * s,
          height: (g.ny != 0 ? 6 : g.halfWidth * 2) * s);
      canvas.drawRect(
          mouth,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 * s);
      canvas.drawRect(mouth, Paint()..color = ownerColor.withValues(alpha: 0.18));
    }

    // pull-back aim line while dragging
    if (dragging && pull.distance > 1) {
      final seat = m.currentSeat;
      final d = m.discs[seat];
      final capped = min(pull.distance, FlickSoccerMatch.maxPull);
      final dir = -pull / pull.distance;
      canvas.drawLine(
        P(d.x, d.y),
        P(d.x + dir.dx * capped * 1.6, d.y + dir.dy * capped * 1.6),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // discs: black rim, player color, white star
    for (var i = 0; i < m.discs.length; i++) {
      final d = m.discs[i];
      final c = P(d.x, d.y);
      final isTurn = i == m.currentSeat && !m.over;
      canvas.drawCircle(
          c,
          FlickSoccerMatch.discR * s,
          Paint()..color = const Color(0xFF232323));
      canvas.drawCircle(c, (FlickSoccerMatch.discR - 1.6) * s,
          Paint()..color = colors[i]);
      if (isTurn && m.settled) {
        canvas.drawCircle(
            c,
            (FlickSoccerMatch.discR + 2.2) * s,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
      _star(canvas, c, (FlickSoccerMatch.discR - 3.4) * s);
    }

    // ball
    final bc = P(m.ball.x, m.ball.y);
    final br = FlickSoccerMatch.ballR * s;
    canvas.drawCircle(bc, br, Paint()..color = const Color(0xFF232323));
    canvas.drawCircle(bc, br * 0.86, Paint()..color = Colors.white);
    canvas.drawCircle(bc, br * 0.3, Paint()..color = const Color(0xFF232323));
    for (var k = 0; k < 5; k++) {
      final a = k * 2 * pi / 5 - pi / 2;
      canvas.drawCircle(
          bc + Offset(cos(a), sin(a)) * br * 0.62, br * 0.16,
          Paint()..color = const Color(0xFF232323));
    }
  }

  void _star(Canvas canvas, Offset c, double r) {
    final path = Path();
    for (var k = 0; k < 10; k++) {
      final rad = k.isEven ? r : r * 0.45;
      final a = k * pi / 5 - pi / 2;
      final p = c + Offset(cos(a) * rad, sin(a) * rad);
      if (k == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) => true;
}

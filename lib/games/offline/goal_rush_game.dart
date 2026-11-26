import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import 'goal_rush_logic.dart';

/// جري الجون: faithful clone of the reference's "Goal Rush" - let go to
/// turn, hold to run, bump the ball into the other seat's goal. First to 3.
/// Original code and flat art.
class GoalRushGame extends StatefulWidget {
  const GoalRushGame({super.key, this.randomSeed});

  final int? randomSeed;

  @override
  State<GoalRushGame> createState() => _GoalRushGameState();
}

enum _Phase { pickPlayers, pickBots, playing, over }

class _GoalRushGameState extends State<GoalRushGame> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  _Phase _phase = _Phase.pickPlayers;
  int _humans = 2;
  late GoalRushMatch _match;
  Timer? _ticker;

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
  GoalRushMatch get debugMatch => _match;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startGame(int humans, bool withBots) {
    _ticker?.cancel();
    _humans = humans;
    final practice = humans == 1 && !withBots;
    final seats = practice ? 1 : (withBots ? 4 : humans);
    final bots = <int>{for (var i = humans; i < seats; i++) i};
    setState(() {
      _match = GoalRushMatch(
        seats: seats,
        random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
      )..botSeats.addAll(bots);
      _phase = _Phase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      setState(() {
        _match.step(0.016);
        if (_match.over) {
          _ticker?.cancel();
          _phase = _Phase.over;
        }
      });
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
          Text('كام لاعب؟ 🥅', style: _t(22, w: FontWeight.w900)),
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
                ? 'لوحدك: قد إيه جون تقدر تسجّله في دقيقة'
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

  /// Hold-to-run pad for one seat. [quarterTurns] rotates the label so the
  /// player on the far side reads it their way.
  Widget _pad(int seat, {int quarterTurns = 0, bool vertical = false}) {
    final color = _colors[seat];
    final holding = _phase == _Phase.playing && _match.runners[seat].holding;
    final label = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🏃',
            style: TextStyle(
                fontSize: 16,
                height: 1.0,
                fontFamilyFallback: _emojiFallback)),
        Text(
          PlayerNames.name(seat),
          textDirection: TextDirection.rtl,
          style: _t(vertical ? 10 : 11, w: FontWeight.w900, color: Colors.white)
              .copyWith(height: 1.1),
        ),
        if (!vertical)
          Text('دوسّ = اجري',
              style: _t(8, w: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85))
                  .copyWith(height: 1.1)),
      ],
    );
    return Listener(
      key: ValueKey('rush_pad_$seat'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => setState(() => _match.setHolding(seat, true)),
      onPointerUp: (_) => setState(() => _match.setHolding(seat, false)),
      onPointerCancel: (_) => setState(() => _match.setHolding(seat, false)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: holding ? color : color.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FlatColors.ink, width: holding ? 3 : 1.5),
        ),
        child: RotatedBox(quarterTurns: quarterTurns, child: label),
      ),
    );
  }

  Widget _scoreChip(int seat) {
    final color = _colors[seat];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        '${_match.botSeats.contains(seat) ? '🤖 ' : ''}${PlayerNames.name(seat)} ${_match.practice ? '🥅${_match.practiceGoals}' : '⚽${_match.scores[seat]}'}',
        textDirection: TextDirection.rtl,
        style: _t(11, w: FontWeight.w900),
      ),
    );
  }

  Widget _playing() {
    final seats = _match.seats;
    final is4 = seats == 4;
    return Column(
      children: [
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          children: [for (var s = 0; s < seats; s++) _scoreChip(s)],
        ),
        // top pads: 2P -> seat 1; 3P -> seats 1+2; 4P -> seat 2 (rotated)
        if (!is4 && seats > 1)
          SizedBox(
            height: 64,
            child: Row(children: [
              for (var s = 1; s < (seats == 3 ? 3 : 2); s++)
                if (!_match.botSeats.contains(s))
                  Expanded(child: _pad(s, quarterTurns: 2))
                else
                  Expanded(child: _botTile(s)),
            ]),
          ),
        Expanded(
          child: Row(children: [
            if (is4)
              SizedBox(
                  width: 58,
                  child: _match.botSeats.contains(3)
                      ? _botTile(3, vertical: true)
                      : _pad(3, quarterTurns: 3, vertical: true)),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio:
                      GoalRushMatch.fieldW / GoalRushMatch.fieldH,
                  child: CustomPaint(
                    key: const ValueKey('rush_field'),
                    painter: _RushPainter(_match, _colors),
                  ),
                ),
              ),
            ),
            if (is4)
              SizedBox(
                  width: 58,
                  child: _match.botSeats.contains(1)
                      ? _botTile(1, vertical: true)
                      : _pad(1, quarterTurns: 1, vertical: true)),
          ]),
        ),
        // bottom pad: always seat 0
        SizedBox(
          height: 64,
          child: Row(children: [
            Expanded(
                child: _match.botSeats.contains(0) ? _botTile(0) : _pad(0)),
          ]),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _botTile(int seat, {bool vertical = false}) {
    final color = _colors[seat];
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5),
      ),
      child: RotatedBox(
        quarterTurns: vertical ? (seat == 3 ? 3 : 1) : 0,
        child: Center(
          child: Text('🤖 ${PlayerNames.name(seat)}',
              textDirection: TextDirection.rtl,
              style: _t(vertical ? 10 : 12, w: FontWeight.w900)),
        ),
      ),
    );
  }

  Widget _buildOver() {
    final w = _match.winner;
    Widget head;
    if (_match.practice) {
      head = Text(
          'سجّلت ${_match.practiceGoals} جون في دقيقة 🥅',
          textAlign: TextAlign.center,
          style: _t(20));
    } else if (w == null) {
      head = Text('انتهى الماتش', style: _t(22));
    } else if (_match.botSeats.contains(w)) {
      head = Text('البوتات كسبوا 🤖', style: _t(22));
    } else {
      head = VictoryFriends(
          gameTitle: 'جري الجون',
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
        title: 'جري الجون',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
          title: 'جري الجون',
          playersLabel: '١-٤ لاعبين',
          showBotsChip: true,
          description:
              'زرار واحد بس: سيبه يلفّ ودوسّه يجري! اجري بالكورة وخبطها في جون الخصم. أول واحد يسجّل ٣ جوون يكسب 🥅',
          icon: '⚽',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }
    return OfflineGameScaffold(
      title: 'جري الجون',
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

/// Top-down pitch: stripes, halfway line, goal boxes, runners, ball.
class _RushPainter extends CustomPainter {
  _RushPainter(this.m, this.colors);

  final GoalRushMatch m;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / GoalRushMatch.fieldW;
    final sy = size.height / GoalRushMatch.fieldH;
    Offset P(double x, double y) => Offset(x * sx, y * sy);

    for (var i = 0; i < 10; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * size.height / 10, size.width, size.height / 10),
        Paint()
          ..color = i.isEven ? const Color(0xFF58A34C) : const Color(0xFF4E9643),
      );
    }
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawLine(P(0, GoalRushMatch.fieldH / 2),
        P(100, GoalRushMatch.fieldH / 2), line);
    canvas.drawCircle(P(50, GoalRushMatch.fieldH / 2), 16 * sx, line);

    for (final g in m.goals) {
      final ownerColor = g.owner >= 0 ? colors[g.owner] : Colors.white;
      final horizontal = g.cy == 0 || g.cy == GoalRushMatch.fieldH;
      final mouth = Rect.fromCenter(
          center: P(g.cx, g.cy),
          width: (horizontal ? g.halfWidth * 2 : 6) * sx,
          height: (horizontal ? 6 : g.halfWidth * 2) * sy);
      canvas.drawRect(mouth, Paint()..color = ownerColor.withValues(alpha: 0.25));
      canvas.drawRect(
          mouth,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
    }

    // runners: top-down dude = body circle, head, direction nose
    for (var i = 0; i < m.runners.length; i++) {
      final r = m.runners[i];
      final c = P(r.x, r.y);
      final rr = GoalRushMatch.runnerR * sx;
      canvas.drawCircle(c, rr, Paint()..color = const Color(0xFF232323));
      canvas.drawCircle(c, rr * 0.86, Paint()..color = colors[i]);
      // head
      canvas.drawCircle(c, rr * 0.42, Paint()..color = const Color(0xFFF2C89B));
      canvas.drawCircle(c, rr * 0.42,
          Paint()
            ..color = const Color(0xFF232323)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
      // facing wedge
      final nose = c + Offset(cos(r.heading), sin(r.heading)) * rr * 1.15;
      canvas.drawCircle(nose, 2.4, Paint()..color = Colors.white);
      if (r.holding) {
        canvas.drawCircle(
            c,
            rr + 3.5,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.65)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
    }

    // ball
    final bc = P(m.ballX, m.ballY);
    final br = GoalRushMatch.ballR * sx;
    canvas.drawCircle(bc, br, Paint()..color = const Color(0xFF232323));
    canvas.drawCircle(bc, br * 0.86, Paint()..color = Colors.white);
    canvas.drawCircle(bc, br * 0.3, Paint()..color = const Color(0xFF232323));
    for (var k = 0; k < 5; k++) {
      final a = k * 2 * pi / 5 - pi / 2;
      canvas.drawCircle(bc + Offset(cos(a), sin(a)) * br * 0.62, br * 0.16,
          Paint()..color = const Color(0xFF232323));
    }
  }

  @override
  bool shouldRepaint(covariant _RushPainter old) => true;
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import '../../services/arcade_juice.dart';
import 'minigolf_logic.dart';

/// جولف الشلة: turn-based minigolf for 1-4 seats on one phone. Three holes,
/// fewest total strokes wins. Drag from the ball to aim, release to putt.
class MiniGolfGameScreen extends StatefulWidget {
  const MiniGolfGameScreen({super.key});

  @override
  State<MiniGolfGameScreen> createState() => _MiniGolfGameScreenState();
}

enum _GolfPhase { pickPlayers, pickBots, banner, play, over }

class _MiniGolfGameScreenState extends State<MiniGolfGameScreen>
    with SingleTickerProviderStateMixin {
  static const _emojiFallback = ['Noto Color Emoji'];
  static const _felt = Color(0xFF8FD9A8);
  static const _feltDark = Color(0xFF6BC48C);
  static const _wall = Color(0xFFB08968);
  static const _strokeCap = 8;

  bool _showIntro = true;
  _GolfPhase _phase = _GolfPhase.pickPlayers;
  late final List<MiniGolfHole> _course = shellaCourse();
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Timer? _nextTimer;

  int _humans = 2;
  bool _practice = false;
  int _seatCount = 2;
  Set<int> _bots = {};
  int _hole = 0;
  int _seat = 0;
  late List<List<int>> _strokes; // [seat][hole]
  Offset? _aim; // current drag vector (logical px)
  Offset? _dragStart;
  double _scale = 1;
  bool _gaveUp = false;

  static const List<Color> _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  // Debug-only accessors for widget tests.
  double get debugScale => _scale;
  MiniGolfHole get debugHole => _h;
  int get debugSeatCount => _seatCount;
  Set<int> get debugBots => _bots;

  MiniGolfHole get _h => _course[_hole];

  String _seatLabel(int seat) =>
      _bots.contains(seat) ? 'بوت ${seat + 1}' : PlayerNames.name(seat);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _nextTimer?.cancel();
    super.dispose();
  }

    void _juiceEnd() {
    if (_practice) {
      ArcadeJuice.win();
      return;
    }
    final totals = [
      for (var st = 0; st < _seatCount; st++)
        _strokes[st].fold(0, (a, b) => a + b),
    ];
    final best = totals.fold(999, (a, b) => a < b ? a : b);
    final humanWin = [
      for (var i = 0; i < _seatCount; i++)
        if (totals[i] == best && !_bots.contains(i)) i,
    ].isNotEmpty;
    humanWin ? ArcadeJuice.win() : ArcadeJuice.lose();
  }

void _startMatch(int humans, bool withBots) {
    ArcadeJuice.tap();
    _humans = humans;
    _practice = humans == 1 && !withBots;
    _seatCount = _practice ? 1 : (withBots ? 4 : humans);
    _bots = {
      for (var i = humans; i < _seatCount && (withBots || _practice); i++) i,
    };
    _strokes = List.generate(_seatCount, (_) => List.filled(_course.length, 0));
    _hole = 0;
    _seat = 0;
    _h.reset();
    setState(() => _phase = _GolfPhase.banner);
    if (_bots.contains(_seat)) _autoPlay();
  }

  void _autoPlay() {
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 700), _botShot);
  }

  void _botShot() {
    if (!mounted || _phase != _GolfPhase.play || !_bots.contains(_seat)) {
      if (_phase == _GolfPhase.banner) {
        setState(() => _phase = _GolfPhase.play);
        _autoPlay();
      }
      return;
    }
    // Aim straight at the cup with a seeded error; power by distance.
    final dx = _h.holePos.$1 - _h.ballX;
    final dy = _h.holePos.$2 - _h.ballY;
    final dist = sqrt(dx * dx + dy * dy);
    final err = (Random().nextDouble() - 0.5) * 26; // degrees
    final angle = atan2(dy, dx) * 180 / pi + err;
    // Power: stop near the cup. v^2 = 2*a*d (+ cup margin), capped.
    final v = sqrt(2 * MiniGolfHole.friction * (dist * 0.94));
    final power = (v / MiniGolfHole.maxPower).clamp(0.08, 1.0);
    _h.shoot(angle, power);
    _startTicker();
  }

  void _startTicker() {
    _lastTick = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (_phase != _GolfPhase.play) return;
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    setState(() => _h.step(dt.clamp(0, 1 / 20)));
    if (_h.resting || _h.sunk) {
      _ticker.stop();
      _afterBallStops();
    }
  }

  void _afterBallStops() {
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || _phase != _GolfPhase.play) return;
      if (!_h.sunk && _h.strokes >= _strokeCap) {
        // Stroke cap reached: hole over for this seat.
        _finishHoleForSeat(_strokeCap);
      } else if (_h.sunk) {
        _finishHoleForSeat(_h.strokes);
      } else if (_bots.contains(_seat)) {
        _autoPlay();
      }
    });
  }

  void _finishHoleForSeat(int strokes) {
    _strokes[_seat][_hole] = strokes;
    setState(() {
      if (_seat + 1 < _seatCount) {
        _seat++;
        _h.reset();
        _phase = _GolfPhase.banner;
      } else if (_hole + 1 < _course.length) {
        _hole++;
        _seat = 0;
        _h.reset();
        _phase = _GolfPhase.banner;
      } else {
        _phase = _GolfPhase.over;
        _juiceEnd();
      }
      _gaveUp = false;
    });
    if (_phase == _GolfPhase.banner && _bots.contains(_seat)) _autoPlay();
  }

  // --- aiming (human turns) ---
  Offset _toLogical(Offset p) => Offset(p.dx / _scale, p.dy / _scale);

  void _onPanStart(DragStartDetails d) {
    if (_bots.contains(_seat) || !_h.resting) return;
    final p = _toLogical(d.localPosition);
    if ((p - Offset(_h.ballX, _h.ballY)).distance < 60) {
      _dragStart = Offset(_h.ballX, _h.ballY);
      setState(() => _aim = Offset.zero);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragStart == null) return;
    setState(() => _aim = _toLogical(d.localPosition) - _dragStart!);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_dragStart == null) return;
    final aim = _aim ?? Offset.zero;
    _dragStart = null;
    setState(() => _aim = null);
    if (aim.distance < 12) return; // too small a drag
    // Slingshot: shoot opposite the drag.
    final angle = atan2(-aim.dy, -aim.dx) * 180 / pi;
    final power = (aim.distance / 200).clamp(0.05, 1.0);
    _h.shoot(angle, power);
    _startTicker();
  }

  TextStyle _t(double size,
          {Color? color, FontWeight w = FontWeight.w800, double? h}) =>
      flatCairo(fontSize: size, fontWeight: w, color: color ?? FlatColors.ink)
          .copyWith(fontFamilyFallback: _emojiFallback, height: h);

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: 'جولف الشلة',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
          icon: '⛳',
          title: 'جولف الشلة',
          playersLabel: '١-٤ لاعبين',
          showBotsChip: true,
          description:
              '٣ حفر وكل واحد يلعبها بالتناوب! اسحب من الكورة عشان تصوّب وارمي. أقل عدد ضربات في الآخر يكسب ⛳',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }
    return OfflineGameScaffold(
      title: 'جولف الشلة',
      backgroundColor: FlatColors.bg,
      body: switch (_phase) {
        _GolfPhase.pickPlayers => _pickPlayers(),
        _GolfPhase.pickBots => _pickBots(),
        _GolfPhase.banner => _banner(),
        _GolfPhase.play => _course2d(),
        _GolfPhase.over => _over(),
      },
    );
  }

  Widget _pickPlayers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('كام لاعب؟ ⛳', style: _t(22, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('٣ حفر.. أقل ضربات يكسب',
              style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6))),
          const SizedBox(height: 20),
          for (final n in [1, 2, 3, 4])
            _bigChoice(n == 1 ? 'لاعب واحد' : '$n لاعبين', () {
              if (n == 4) {
                _startMatch(4, false);
              } else {
                setState(() {
                  _humans = n;
                  _phase = _GolfPhase.pickBots;
                });
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
          Text('البوتات تلعب كمان؟ 🤖', style: _t(20, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            _humans == 1 ? 'لوحدك: تمرين على الحفر' : 'البوتات تدخل المنافسة',
            style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () => _startMatch(_humans, true)),
          _bigChoice('لا', () => _startMatch(_humans, false)),
        ],
      ),
    );
  }

  Widget _bigChoice(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: 220,
          child: FilledButton(
              onPressed: onTap,
              child: Text(label, style: _t(18, color: Colors.white))),
        ),
      );

  Widget _banner() {
    final isBot = _bots.contains(_seat);
    return GestureDetector(
      onTap: isBot
          ? null
          : () => setState(() => _phase = _GolfPhase.play),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('حفرة ${_hole + 1} من ${_course.length}',
                style: _t(15, color: FlatColors.ink.withValues(alpha: 0.6)),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _colors[_seat].withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _colors[_seat], width: 2),
              ),
              child: Text(
                'دور ${_seatLabel(_seat)}${isBot ? ' 🤖' : ''}',
                style: _t(22, w: FontWeight.w900, color: _colors[_seat]),
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isBot ? 'البوت بيلعب…' : 'دوس للبدء 👆',
              style: _t(16, w: FontWeight.w900),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      ),
    );
  }

  Widget _course2d() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_seatLabel(_seat)}: ${_h.strokes} ضربات',
                  style: _t(15, w: FontWeight.w900, color: _colors[_seat]),
                  textDirection: TextDirection.rtl),
              Text('حفرة ${_hole + 1}/${_course.length}',
                  style: _t(13, color: FlatColors.ink.withValues(alpha: 0.55)),
                  textDirection: TextDirection.rtl),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _scale = min(constraints.maxWidth / _h.worldWidth,
                  constraints.maxHeight / _h.worldHeight);
              return Center(
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    size: Size(_h.worldWidth * _scale, _h.worldHeight * _scale),
                    painter: _GolfPainter(
                      hole: _h,
                      felt: _felt,
                      feltDark: _feltDark,
                      wall: _wall,
                      ballColor: _colors[_seat],
                      aim: _aim,
                      ink: FlatColors.ink,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (!_bots.contains(_seat) && _h.resting && _h.strokes >= 3)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextButton(
              onPressed: () => _finishHoleForSeat(_strokeCap),
              child: Text('استسلم من الحفرة ($_strokeCap ضربات)',
                  style: _t(13, color: FlatColors.ink.withValues(alpha: 0.55)),
                  textDirection: TextDirection.rtl),
            ),
          ),
      ],
    );
  }

  Widget _over() {
    final totals = [
      for (var s = 0; s < _seatCount; s++)
        _strokes[s].fold(0, (a, b) => a + b),
    ];
    if (_practice) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('خلصت الجولة! ⛳', style: _t(26, w: FontWeight.w900),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 8),
            Text('لعبتها في ${totals[0]} ضربة',
                style: _t(15, color: FlatColors.ink.withValues(alpha: 0.7)),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 20),
            _bigChoice('العب تاني 🔁',
                () => setState(() => _phase = _GolfPhase.pickPlayers)),
          ],
        ),
      );
    }
    final best = totals.fold(999, (a, b) => a < b ? a : b);
    final winners = [
      for (var i = 0; i < _seatCount; i++)
        if (totals[i] == best) i,
    ];
    final humanWinners = winners.where((w) => !_bots.contains(w)).toList();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (humanWinners.isNotEmpty)
            VictoryFriends(
              gameTitle: 'جولف الشلة',
              winnerName: humanWinners.map(_seatLabel).join(' و '),
              winnerSeats: humanWinners,
            )
          else ...[
            Text('البوتات كسبوا 🤖', style: _t(24, w: FontWeight.w900),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 8),
            Text('بوت ${winners.first + 1} خلّص في $best ضربة',
                style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6)),
                textDirection: TextDirection.rtl),
          ],
          const SizedBox(height: 12),
          for (var i = 0; i < _seatCount; i++)
            Text('${_seatLabel(i)}: ${totals[i]} ضربة',
                style: _t(15,
                    w: FontWeight.w900,
                    color: winners.contains(i)
                        ? _colors[i]
                        : FlatColors.ink.withValues(alpha: 0.55)),
                textDirection: TextDirection.rtl),
          const SizedBox(height: 16),
          _bigChoice('العبوا تاني 🔁',
              () => setState(() => _phase = _GolfPhase.pickPlayers)),
        ],
      ),
    );
  }
}

class _GolfPainter extends CustomPainter {
  _GolfPainter({
    required this.hole,
    required this.felt,
    required this.feltDark,
    required this.wall,
    required this.ballColor,
    required this.aim,
    required this.ink,
  });

  final MiniGolfHole hole;
  final Color felt, feltDark, wall, ballColor, ink;
  final Offset? aim;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / hole.worldWidth;
    final sy = size.height / hole.worldHeight;
    final s = min(sx, sy);

    // Felt with border.
    final rr = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(18));
    canvas.drawRRect(rr, Paint()..color = felt);
    canvas.drawRRect(
        rr,
        Paint()
          ..color = feltDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6);

    // Cup.
    final cup = Offset(hole.holePos.$1 * s, hole.holePos.$2 * s);
    canvas.drawCircle(cup, MiniGolfHole.holeRadius * s, Paint()..color = ink);
    // Flag pole + pennant.
    canvas.drawRect(
        Rect.fromLTWH(cup.dx - 1, cup.dy - 46 * s, 2, 46 * s),
        Paint()..color = ink);
    final flag = Path()
      ..moveTo(cup.dx + 1, cup.dy - 46 * s)
      ..lineTo(cup.dx + 22 * s, cup.dy - 39 * s)
      ..lineTo(cup.dx + 1, cup.dy - 32 * s)
      ..close();
    canvas.drawPath(flag, Paint()..color = const Color(0xFFFF5C5C));

    // Walls.
    for (final w in hole.walls) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w.left * s, w.top * s, w.right * s, w.bottom * s),
          const Radius.circular(6),
        ),
        Paint()..color = wall,
      );
    }

    // Aim arrow.
    if (aim != null && aim!.distance > 8) {
      final ball = Offset(hole.ballX * s, hole.ballY * s);
      final dir = -aim! * s;
      final len = dir.distance.clamp(0.0, 140.0);
      final unit = dir / dir.distance;
      final p = Paint()
        ..color = ink.withValues(alpha: 0.7)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(ball, ball + unit * len, p);
      // arrow head
      final head = Path()
        ..moveTo(ball.dx + unit.dx * len + 10 * unit.dx,
            ball.dy + unit.dy * len + 10 * unit.dy)
        ..lineTo(ball.dx + unit.dx * (len - 8) - 6 * -unit.dy,
            ball.dy + unit.dy * (len - 8) - 6 * unit.dx)
        ..lineTo(ball.dx + unit.dx * (len - 8) + 6 * -unit.dy,
            ball.dy + unit.dy * (len - 8) + 6 * unit.dx)
        ..close();
      canvas.drawPath(head, p..style = PaintingStyle.fill);
    }

    // Ball with seat-colored ring.
    if (!hole.sunk) {
      final b = Offset(hole.ballX * s, hole.ballY * s);
      canvas.drawCircle(b, MiniGolfHole.ballRadius * s + 3,
          Paint()..color = ballColor);
      canvas.drawCircle(
          b, MiniGolfHole.ballRadius * s, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _GolfPainter old) => true;
}

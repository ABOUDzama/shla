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
import 'penguins_logic.dart';

/// حرب البطاريق: snowball duel for 1-2 seats on one phone. Lob snowballs
/// over the iceberg; first direct hit wins. Practice mode vs a dummy.
class PenguinsGameScreen extends StatefulWidget {
  const PenguinsGameScreen({super.key});

  @override
  State<PenguinsGameScreen> createState() => _PenguinsGameScreenState();
}

enum _PengPhase { pickPlayers, pickBots, play, over }

class _PenguinsGameScreenState extends State<PenguinsGameScreen>
    with SingleTickerProviderStateMixin {
  static const _emojiFallback = ['Noto Color Emoji'];
  static const _water = Color(0xFFB9E4FF);
  static const _ice = Color(0xFFFFFFFF);
  static const _iceShade = Color(0xFFDCEFF7);

  bool _showIntro = true;
  _PengPhase _phase = _PengPhase.pickPlayers;
  final PenguinDuel _duel = PenguinDuel();
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Timer? _botTimer;

  int _humans = 2;
  bool _practice = false; // 1P vs dummy (never shoots)
  bool _vsBot = false;
  String _lastOutcome = '';
  Offset? _aim;
  Offset? _dragStart;
  double _scale = 1;

  static const List<Color> _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
  ];

  // Debug-only accessor for widget tests.
  bool get debugFlying => _duel.flying;

  bool get _botTurn => _vsBot && _duel.turn == 1 && !_practice;

  String _seatLabel(int seat) => (_vsBot && seat == 1)
      ? (_practice ? 'الدمية 🎯' : 'بوت 2')
      : PlayerNames.name(seat);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _botTimer?.cancel();
    super.dispose();
  }

    void _juiceEnd() {
    final w = _duel.winner;
    if (w == null) return;
    final humanWinner = !(_vsBot && w == 1) || _practice;
    humanWinner ? ArcadeJuice.win() : ArcadeJuice.lose();
  }

void _startMatch(int humans, bool withBots) {
    ArcadeJuice.tap();
    _humans = humans;
    _practice = humans == 1 && !withBots;
    _vsBot = humans == 1;
    _duel
      ..turn = 0
      ..winner = null
      ..flying = false;
    _lastOutcome = '';
    setState(() => _phase = _PengPhase.play);
  }

  void _onTick(Duration elapsed) {
    if (_phase != _PengPhase.play || !_duel.flying) return;
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final outcome = _duel.step(dt.clamp(0, 1 / 20).toDouble());
    setState(() {});
    if (outcome != null) {
      _ticker.stop();
      _lastOutcome = switch (outcome) {
        'hit' => 'هدف مباشر! 🎯',
        'berg' => 'الجبل حجب الكرة 🧊',
        _ => 'وقعت في المية 💦',
      };
      if (_duel.winner != null) {
        setState(() => _phase = _PengPhase.over);
        _juiceEnd();
      } else {
        _scheduleBot();
      }
    }
  }

  void _scheduleBot() {
    if (!_botTurn) return;
    _botTimer?.cancel();
    _botTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || _phase != _PengPhase.play || _duel.winner != null) {
        return;
      }
      final err = Random().nextDouble() * 30 - 15;
      final (angle, power) = _duel.botAim(error: err);
      _duel.shoot(angle, power);
      _startTicker();
    });
  }

  void _startTicker() {
    _lastTick = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  Offset _toWorld(Offset p, Size paintSize) => Offset(p.dx / _scale, p.dy / _scale);

  void _onPanStart(DragStartDetails d) {
    if (_botTurn || _duel.flying || _duel.winner != null) return;
    if (_practice && _duel.turn == 1) return;
    final w = _toWorld(d.localPosition, Size.zero);
    final p = _duel.penguinPos(_duel.turn);
    if ((Offset(p.$1, p.$2) - w).distance < 70) {
      _dragStart = w;
      setState(() => _aim = Offset.zero);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragStart == null) return;
    setState(() => _aim = _toWorld(d.localPosition, Size.zero) - _dragStart!);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_dragStart == null) return;
    final aim = _aim ?? Offset.zero;
    _dragStart = null;
    setState(() => _aim = null);
    if (aim.distance < 12) return;
    // Slingshot: shoot opposite the drag, angle above horizontal.
    final dir = _duel.turn == 0 ? 1.0 : -1.0;
    final dx = -aim.dx * dir;
    final dy = -aim.dy;
    if (dx <= 0 || dy >= 0) return; // must pull back-down
    final angle = atan2(-dy, dx.abs()) * 180 / pi;
    final power = (aim.distance / 180).clamp(0.1, 1.0);
    _duel.shoot(angle, power);
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
        title: 'حرب البطاريق',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
          icon: '🐧',
          title: 'حرب البطاريق',
          playersLabel: '١-٢ لاعب',
          showBotsChip: true,
          description:
              'بطريقان على الجليد وكرات تلج بتطير فوق الجبل! اسحب من البطريق عشان تصوّب.. أول واحد يصيب التاني يكسب 🐧',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }
    return OfflineGameScaffold(
      title: 'حرب البطاريق',
      backgroundColor: FlatColors.bg,
      body: switch (_phase) {
        _PengPhase.pickPlayers => _pickPlayers(),
        _PengPhase.pickBots => _pickBots(),
        _PengPhase.play => _arena(),
        _PengPhase.over => _over(),
      },
    );
  }

  Widget _pickPlayers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('كام لاعب؟ 🐧', style: _t(22, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('مبارزة واحد لواحد على نفس الموبايل',
              style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6))),
          const SizedBox(height: 20),
          _bigChoice('لاعب واحد', () {
            setState(() {
              _humans = 1;
              _phase = _PengPhase.pickBots;
            });
          }),
          _bigChoice('2 لاعبين', () => _startMatch(2, false)),
        ],
      ),
    );
  }

  Widget _pickBots() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('تتحدى مين؟ 🤖', style: _t(20, w: FontWeight.w900)),
          const SizedBox(height: 20),
          _bigChoice('بوت يرمي كمان 🤖', () => _startMatch(1, true)),
          _bigChoice('دمية تمرين 🎯', () => _startMatch(1, false)),
        ],
      ),
    );
  }

  Widget _bigChoice(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: 240,
          child: FilledButton(
              onPressed: onTap,
              child: Text(label, style: _t(17, color: Colors.white))),
        ),
      );

  Widget _arena() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _colors[_duel.turn].withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _colors[_duel.turn], width: 1.5),
                ),
                child: Text('دور ${_seatLabel(_duel.turn)}',
                    style:
                        _t(14, w: FontWeight.w900, color: _colors[_duel.turn]),
                    textDirection: TextDirection.rtl),
              ),
              if (_lastOutcome.isNotEmpty)
                Text(_lastOutcome,
                    style:
                        _t(13, color: FlatColors.ink.withValues(alpha: 0.55)),
                    textDirection: TextDirection.rtl),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _scale = min(constraints.maxWidth / _duel.worldWidth,
                  constraints.maxHeight / _duel.worldHeight);
              final w = _duel.worldWidth * _scale;
              final h = _duel.worldHeight * _scale;
              return Center(
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    size: Size(w, h),
                    painter: _PenguinPainter(
                      duel: _duel,
                      water: _water,
                      ice: _ice,
                      iceShade: _iceShade,
                      colors: _colors,
                      aim: _aim,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            _botTurn
                ? 'البوت بيصوّب…'
                : (_practice && _duel.turn == 1
                    ? 'الدمية مستنية تتصاب 😅'
                    : 'اسحب من البطريق ورمي كرة التلج! 🧊'),
            style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6)),
            textDirection: TextDirection.rtl,
          ),
        ),
      ],
    );
  }

  Widget _over() {
    final w = _duel.winner ?? 0;
    final humanWinner = !(_vsBot && w == 1) || _practice;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_practice) ...[
            Text('أصبت الدمية! 🎯', style: _t(26, w: FontWeight.w900),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 8),
            Text('تصويبك بقى جاهز للتحدي الحقيقي',
                style: _t(14, color: FlatColors.ink.withValues(alpha: 0.6)),
                textDirection: TextDirection.rtl),
          ] else if (humanWinner)
            VictoryFriends(
              gameTitle: 'حرب البطاريق',
              winnerName: _seatLabel(w),
              winnerSeats: [w],
            )
          else ...[
            BotsWinLabel(gameTitle: 'حرب البطاريق',
                style: _t(24, w: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('كرة التلج بتاعته كانت أدق',
                style: _t(13, color: FlatColors.ink.withValues(alpha: 0.6)),
                textDirection: TextDirection.rtl),
          ],
          const SizedBox(height: 20),
          _bigChoice('العبوا تاني 🔁',
              () => setState(() => _phase = _PengPhase.pickPlayers)),
        ],
      ),
    );
  }
}

class _PenguinPainter extends CustomPainter {
  _PenguinPainter({
    required this.duel,
    required this.water,
    required this.ice,
    required this.iceShade,
    required this.colors,
    required this.aim,
  });

  final PenguinDuel duel;
  final Color water, ice, iceShade;
  final List<Color> colors;
  final Offset? aim;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / duel.worldWidth;
    canvas.drawRect(Offset.zero & size, Paint()..color = water);

    // Center iceberg (triangle).
    final berg = Path()
      ..moveTo((duel.centerX - PenguinDuel.peakHalfWidth) * s,
          PenguinDuel.floeY * s)
      ..lineTo(duel.centerX * s, PenguinDuel.peakY * s)
      ..lineTo((duel.centerX + PenguinDuel.peakHalfWidth) * s,
          PenguinDuel.floeY * s)
      ..close();
    canvas.drawPath(berg, Paint()..color = iceShade);

    // Floes.
    for (final seat in [0, 1]) {
      final p = duel.penguinPos(seat);
      final floe = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(p.$1 * s, PenguinDuel.floeY * s + 8 * s),
            width: 110 * s,
            height: 20 * s),
        Radius.circular(10 * s),
      );
      canvas.drawRRect(floe, Paint()..color = ice);
      // Penguin emoji, flipped for seat 1.
      final tp = TextPainter(
        text: TextSpan(
            text: '🐧',
            style: TextStyle(
                fontSize: PenguinDuel.penguinR * 2.2 * s,
                fontFamilyFallback: const ['Noto Color Emoji'])),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(p.$1 * s, (p.$2) * s);
      if (seat == 1) canvas.scale(-1, 1);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      // Seat color ring under penguin.
      canvas.drawCircle(Offset(p.$1 * s, (p.$2 + PenguinDuel.penguinR) * s),
          4 * s, Paint()..color = colors[seat]);
    }

    // Aim arrow.
    if (aim != null && aim!.distance > 8 && !duel.flying) {
      final p = duel.penguinPos(duel.turn);
      final ball = Offset(p.$1 * s, p.$2 * s);
      final dir = -aim! * s;
      final len = dir.distance.clamp(0.0, 110.0);
      final unit = dir / dir.distance;
      final paint = Paint()
        ..color = Colors.black54
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(ball, ball + unit * len, paint);
    }

    // Flying snowball.
    if (duel.flying) {
      canvas.drawCircle(
          Offset(duel.ballX * s, duel.ballY * s),
          8 * s,
          Paint()..color = ice);
      canvas.drawCircle(
          Offset(duel.ballX * s, duel.ballY * s),
          8 * s,
          Paint()
            ..color = Colors.black26
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant _PenguinPainter old) => true;
}

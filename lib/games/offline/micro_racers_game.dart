import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import 'micro_racers_logic.dart';

/// ميكرو ريسرز: faithful clone of the reference app's "Micro Speed
/// Racers" - one button per player cycles three lanes, dodge blocks and
/// oil, collect batteries, hit boost pads, first to the finish wins.
/// Original code and flat art.
class MicroRacersGame extends StatefulWidget {
  const MicroRacersGame({super.key, this.randomSeed});

  final int? randomSeed;

  @override
  State<MicroRacersGame> createState() => _MicroRacersGameState();
}

enum _Phase { pickPlayers, pickBots, playing, over }

class _MicroRacersGameState extends State<MicroRacersGame> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  _Phase _phase = _Phase.pickPlayers;
  int _humans = 2;
  bool _practice = false;
  late MicroRaceMatch _match;
  Timer? _ticker;
  Timer? _botTimer;

  static const List<Color> _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  TextStyle _t(double size,
          {FontWeight w = FontWeight.w800, Color color = FlatColors.ink}) =>
      flatCairo(fontSize: size, fontWeight: w, color: color)
          .copyWith(fontFamilyFallback: _emojiFallback);

  @visibleForTesting
  MicroRaceMatch get debugMatch => _match;

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
    _practice = humans == 1 && !withBots;
    final seats = _practice ? 1 : (withBots ? 4 : humans);
    final bots = <int>{
      for (var i = humans; i < seats && (withBots || _practice); i++) i,
    };
    setState(() {
      _match = MicroRaceMatch(
        seats: seats,
        random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
      )..botSeats.addAll(bots);
      _phase = _Phase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) return;
      setState(() {
        _match.step(0.033);
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
          Text('كام لاعب؟ 🏎', style: _t(22, w: FontWeight.w900)),
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
                ? 'لوحدك: تمرين من غير نتيجة'
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

  Widget _strip(int seat) {
    final c = _match.cars[seat];
    final isHuman = seat < _humans;
    final color = _colors[seat];
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        child: GestureDetector(
          key: ValueKey('lane_tap_$seat'),
          onTap: (isHuman && _phase == _Phase.playing)
              ? () => setState(() => _match.cycleLane(seat))
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: color.withValues(alpha: 0.7), width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(builder: (context, bc) {
              return Stack(
                children: [
                  Positioned.fill(
                      child: CustomPaint(
                          painter: _StripPainter(_match, seat, color))),
                  // Player chip: name + batteries + progress
                  Positioned(
                    top: 4,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_match.botSeats.contains(seat) ? '🤖 ' : ''}${PlayerNames.name(seat)} · 🔋${c.batteries}',
                        textDirection: TextDirection.rtl,
                        style: _t(11, w: FontWeight.w900, color: FlatColors.ink),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 6,
                    child: Text(
                      '${(c.dist / _match.trackLength * 100).clamp(0, 100).round()}٪',
                      style: _t(11,
                          w: FontWeight.w900,
                          color: FlatColors.ink.withValues(alpha: 0.55)),
                    ),
                  ),
                  if (isHuman && _phase == _Phase.playing)
                    Positioned(
                      bottom: 4,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          'دوس بدّل المسار 👆',
                          style: _t(10,
                              w: FontWeight.w800,
                              color: FlatColors.ink.withValues(alpha: 0.45)),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _playing() {
    return Column(
      children: [
        for (var s = 0; s < _match.seats; s++) _strip(s),
      ],
    );
  }

  Widget _buildOver() {
    final w = _match.winner;
    Widget head;
    if (_practice) {
      final c = _match.cars[0];
      head = Text(
          'وصلت النهاية في ${c.finishedAt.toStringAsFixed(1)} ثانية وجمعت ${c.batteries} بطارية 🔋',
          textAlign: TextAlign.center,
          style: _t(20));
    } else if (w == null) {
      head = Text('انتهى السباق', style: _t(22));
    } else if (_match.botSeats.contains(w)) {
      head = Text('البوتات كسبوا 🤖', style: _t(22));
    } else {
      head = VictoryFriends(
          gameTitle: 'ميكرو ريسرز',
          winnerName: PlayerNames.name(w),
          winnerSeats: [w]);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      head,
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => setState(() => _phase = _Phase.pickPlayers),
        child: Text('العبوا تاني 🏁', style: _t(18, color: Colors.white)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: 'ميكرو ريسرز',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
          title: 'ميكرو ريسرز',
          playersLabel: '١-٤ لاعبين',
          showBotsChip: true,
          description:
              'سباق ميني بزرار واحد لكل لاعب: دوس عشان تبدّل بين ٣ حارات (شمال، نص، يمين). اهرب من الصناديق 🚧 وبقع الزيت 🛢 ولمّ البطاريات 🔋 وعدّي على أسهم السرعة ⚡ وأول واحد يوصل خط النهاية يكسب',
          icon: '🏎',
          onStart: () => setState(() => _showIntro = false),
        ),
      );
    }
    return OfflineGameScaffold(
      title: 'ميكرو ريسرز',
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

/// One player's mini track: three scrolling lanes, items, the car.
class _StripPainter extends CustomPainter {
  _StripPainter(this.m, this.seat, this.color);

  final MicroRaceMatch m;
  final int seat;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = m.cars[seat];
    final laneW = size.width / 3;
    // track surface
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFF3F6FA));
    // lane separators
    final sep = Paint()
      ..color = const Color(0xFFCFD8E3)
      ..strokeWidth = 2;
    for (var i = 1; i < 3; i++) {
      var y = 6.0;
      while (y < size.height) {
        canvas.drawLine(Offset(laneW * i, y), Offset(laneW * i, y + 10), sep);
        y += 22;
      }
    }
    // finish line near the top when the car approaches the end
    final visibleAhead = 34.0; // track units visible above the car
    final carY = size.height - 26.0;
    double yOf(double dist) =>
        carY - (dist - c.dist) / visibleAhead * (size.height - 40);

    // items
    for (final it in m.items[seat]) {
      if (it.taken) continue;
      final y = yOf(it.dist);
      if (y < -20 || y > size.height + 20) continue;
      final cx = laneW * (it.lane + 0.5);
      switch (it.type) {
        case MicroItemType.block:
          final r = Rect.fromCenter(center: Offset(cx, y), width: 30, height: 22);
          canvas.drawRRect(
              RRect.fromRectAndRadius(r, const Radius.circular(4)),
              Paint()..color = const Color(0xFFB08968));
          canvas.drawRRect(
              RRect.fromRectAndRadius(r, const Radius.circular(4)),
              Paint()
                ..color = FlatColors.ink
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2);
        case MicroItemType.oil:
          canvas.drawOval(
              Rect.fromCenter(center: Offset(cx, y), width: 30, height: 14),
              Paint()..color = const Color(0xFF3A3A44));
        case MicroItemType.battery:
          final r = Rect.fromCenter(center: Offset(cx, y), width: 14, height: 24);
          canvas.drawRRect(
              RRect.fromRectAndRadius(r, const Radius.circular(3)),
              Paint()..color = const Color(0xFF43AA8B));
          canvas.drawRect(
              Rect.fromCenter(
                  center: Offset(cx, y - 13), width: 6, height: 4),
              Paint()..color = const Color(0xFF43AA8B));
        case MicroItemType.boost:
          final path = Path()
            ..moveTo(cx - 12, y + 8)
            ..lineTo(cx, y - 8)
            ..lineTo(cx + 12, y + 8)
            ..close();
          canvas.drawPath(path, Paint()..color = const Color(0xFFFFC93C));
          canvas.drawPath(
              path,
              Paint()
                ..color = FlatColors.ink
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.6);
      }
    }

    // the car (small formula car, original flat art)
    final carX = laneW * (c.lane + 0.5);
    canvas.save();
    canvas.translate(carX, carY);
    final boosting = m.time < c.boostUntil;
    if (boosting) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 18), width: 12, height: 14),
        Paint()..color = const Color(0xFFFFC93C),
      );
    }
    // wheels
    final wheel = Paint()..color = const Color(0xFF2B2B30);
    for (final wx in [-9.0, 9.0]) {
      for (final wy in [-10.0, 8.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(wx - 3.5, wy - 3, 7, 8),
              const Radius.circular(2)),
          wheel,
        );
      }
    }
    // body
    final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 18, height: 30),
        const Radius.circular(6));
    canvas.drawRRect(body, Paint()..color = color);
    canvas.drawRRect(
        body,
        Paint()
          ..color = FlatColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    // cockpit
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, -2), width: 9, height: 12),
        Paint()..color = Colors.white.withValues(alpha: 0.92));
    // front wing
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-12, -17, 24, 5), const Radius.circular(2)),
      Paint()..color = FlatColors.ink,
    );
    // block-hit flash: red ring
    if (m.time < c.slowUntil) {
      canvas.drawCircle(
          Offset.zero,
          22,
          Paint()
            ..color = Colors.red.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StripPainter old) => true;
}

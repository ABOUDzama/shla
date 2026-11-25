import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import 'snake_arena_logic.dart';

/// حية الشلة: 1-4 players (+ optional bots), each steers a snake with one
/// turn button placed on their own side of the phone (top buttons rotated
/// to face the players sitting opposite).
class SnakeArenaGame extends StatefulWidget {
  const SnakeArenaGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<SnakeArenaGame> createState() => _SnakeArenaGameState();
}

enum _SnakePhase { pickPlayers, pickBots, playing, over }

class _SnakeArenaGameState extends State<SnakeArenaGame> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  _SnakePhase _phase = _SnakePhase.pickPlayers;
  late SnakeArenaMatch _match;
  Timer? _ticker;
  int _humans = 2;
  bool _practice = false;

  @visibleForTesting
  SnakeArenaMatch get debugMatch => _match;

  static const List<Color> _colors = [
    Color(0xFFFF8A5C),
    Color(0xFF4D8DFF),
    Color(0xFF35C99E),
    Color(0xFFFF6FA5),
  ];

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startMatch(int humans, bool withBots) {
    _ticker?.cancel();
    _humans = humans;
    _practice = humans == 1 && !withBots;
    final seats = _practice ? 1 : (withBots ? 4 : humans);
    final m = SnakeArenaMatch(
      playerCount: seats,
      random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
    );
    for (var i = humans; i < seats && withBots; i++) {
      m.botSeats.add(i);
    }
    setState(() {
      _match = m;
      _phase = _SnakePhase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 220), (_) {
      if (!mounted || _phase != _SnakePhase.playing) return;
      setState(() {
        _match.tick();
        if (_match.isOver) {
          _ticker?.cancel();
          _phase = _SnakePhase.over;
        }
      });
    });
  }

  TextStyle _t(double size, {Color? color, FontWeight w = FontWeight.w800}) =>
      flatCairo(fontSize: size, fontWeight: w, color: color ?? FlatColors.ink)
          .copyWith(fontFamilyFallback: _emojiFallback);

  Widget _bigChoice(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: 220,
          child: FilledButton(onPressed: onTap, child: Text(label, style: _t(18, color: Colors.white))),
        ),
      );

  Widget _buildPicker() => Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('كام لاعب؟', style: _t(26)),
            const SizedBox(height: 20),
            _bigChoice('لاعب واحد', () {
              _humans = 1;
              setState(() => _phase = _SnakePhase.pickBots);
            }),
            for (final n in [2, 3, 4])
              _bigChoice('$n لاعبين', () {
                _humans = n;
                if (n == 4) {
                  _startMatch(4, false);
                } else {
                  setState(() => _phase = _SnakePhase.pickBots);
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
                ? 'من غير بوتات هتلعب لوحدك وتشوف هتجمع كام تفاحة'
                : 'البوتات بتكمّل لحد ٤ لاعبين',
            style: _t(14, w: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () => _startMatch(_humans, true)),
          _bigChoice('لا', () => _startMatch(_humans, false)),
        ]),
      );

  Widget _scorePill(int i) {
    final isBot = _match.botSeats.contains(i);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _colors[i].withValues(alpha: _match.alive[i] ? 0.3 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _match.alive[i] ? _colors[i] : FlatColors.border),
      ),
      child: Text(
        '${isBot ? 'بوت' : 'لاعب'} ${i + 1}: ${_match.score[i]}',
        style: flatCairo(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _match.alive[i] ? FlatColors.ink : FlatColors.ink.withValues(alpha: 0.5),
          decoration: _match.alive[i] ? null : TextDecoration.lineThrough,
        ).copyWith(fontFamilyFallback: _emojiFallback),
      ),
    );
  }

  Widget _turnButton(int i) {
    final active = _phase == _SnakePhase.playing && _match.alive[i];
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          key: Key('snake_turn_$i'),
          style: FilledButton.styleFrom(
            backgroundColor: _colors[i],
            disabledBackgroundColor: _colors[i].withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: active ? () => _match.turn(i) : null,
          child: Text(
            'لاعب ${i + 1} لفّ 🐍',
            style: flatCairo(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
        ),
      ),
    );
  }

  Widget _buildArena() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _SnakePainter(_match, _colors),
        );
      },
    );
  }

  Widget _buildOver() {
    final w = _match.winner;
    Widget head;
    if (_practice) {
      head = Text('جبت ${_match.score[0]} تفاحة 🍎', style: _t(22));
    } else if (w != null && w >= 0 && _match.botSeats.contains(w)) {
      head = Text('البوتات كسبوا 🤖', style: _t(22));
    } else if (w != null && w >= 0) {
      head = VictoryFriends(gameTitle: 'حية الشلة', winnerName: 'لاعب ${w + 1}');
    } else {
      head = Text('تعادل! الكل وقع في بعض 😅', style: _t(20));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        head,
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _phase = _SnakePhase.pickPlayers),
          child: Text('العبوا تاني 🐍', style: _t(18, color: Colors.white)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return GameIntroWidget(
        title: 'حية الشلة',
        description:
            '١-٤ لاعبين على نفس الموبايل، وتقدر تضيف بوتات. كل واحد ليه زرار على جنبه بيلفّ بيه حيته. كل التفاح عشان تكبر، ومتخبطش في الحيطة ولا في حد! آخر حية واقفة تكسب 🐍',
        icon: '🐍',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    if (_phase == _SnakePhase.pickPlayers || _phase == _SnakePhase.pickBots) {
      return OfflineGameScaffold(
        title: 'حية الشلة',
        backgroundColor: FlatColors.bg,
        body: SafeArea(
          child: _phase == _SnakePhase.pickPlayers ? _buildPicker() : _buildBots(),
        ),
      );
    }
    final players = _match.playerCount;
    // Human seats get turn buttons; bots steer themselves. The first half
    // of human seats sits at the bottom, the rest at the top (rotated to
    // face the players opposite).
    final bottomSeats = <int>[];
    final topSeats = <int>[];
    final humanSeats = [for (var i = 0; i < _humans; i++) i];
    final split = (humanSeats.length / 2).ceil();
    bottomSeats.addAll(humanSeats.take(split));
    topSeats.addAll(humanSeats.skip(split));
    return OfflineGameScaffold(
      title: 'حية الشلة',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            if (topSeats.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Transform.rotate(
                  angle: pi,
                  child: Row(children: [
                    // keep left/right seat order natural after rotation
                    for (var i = topSeats.length - 1; i >= 0; i--)
                      _turnButton(topSeats[i]),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [for (var i = 0; i < players; i++) _scorePill(i)],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _phase == _SnakePhase.over
                    ? Center(child: _buildOver())
                    : _buildArena(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Row(children: [for (final i in bottomSeats) _turnButton(i)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnakePainter extends CustomPainter {
  _SnakePainter(this.match, this.colors);

  final SnakeArenaMatch match;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / match.width;
    final ch = size.height / match.height;
    final cell = cw < ch ? cw : ch;
    final ox = (size.width - cell * match.width) / 2;
    final oy = (size.height - cell * match.height) / 2;

    final bg = Paint()..color = FlatColors.tileWhite;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox, oy, cell * match.width, cell * match.height),
        const Radius.circular(12),
      ),
      bg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox, oy, cell * match.width, cell * match.height),
        const Radius.circular(12),
      ),
      Paint()
        ..color = FlatColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    Rect rect(Cell c) => Rect.fromLTWH(
        ox + c.x * cell + 1, oy + c.y * cell + 1, cell - 2, cell - 2);

    final food = match.food;
    if (food != null) {
      final p = Paint()..color = const Color(0xFFFF4D4D);
      canvas.drawCircle(rect(food).center, cell * 0.32, p);
    }

    for (var p = 0; p < match.playerCount; p++) {
      if (!match.alive[p]) continue;
      final body = match.snakes[p];
      for (var i = body.length - 1; i >= 0; i--) {
        final paint = Paint()
          ..color = i == 0 ? colors[p] : colors[p].withValues(alpha: 0.65);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect(body[i]), Radius.circular(cell * 0.25)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SnakePainter oldDelegate) => true;
}

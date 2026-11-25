import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import 'whack_mole_logic.dart';

/// اضرب الخلد: 2-4 players, each whacks moles in their own 2x2 grid.
class WhackMoleGame extends StatefulWidget {
  const WhackMoleGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<WhackMoleGame> createState() => _WhackMoleGameState();
}

enum _MolePhase { pickPlayers, pickBots, playing, over }

class _WhackMoleGameState extends State<WhackMoleGame> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  _MolePhase _phase = _MolePhase.pickPlayers;
  late WhackMoleMatch _match;
  Timer? _ticker;
  int _humans = 2;
  bool _practice = false;

  @visibleForTesting
  WhackMoleMatch get debugMatch => _match;

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
    final m = WhackMoleMatch(
      playerCount: seats,
      random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
    );
    for (var i = humans; i < seats && withBots; i++) {
      m.botSeats.add(i);
    }
    setState(() {
      _match = m;
      _phase = _MolePhase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted || _phase != _MolePhase.playing) return;
      setState(() {
        _match.tick();
        if (_match.isOver) {
          _ticker?.cancel();
          _phase = _MolePhase.over;
        }
      });
    });
  }

  void _whack(int player, int hole) {
    if (_phase != _MolePhase.playing || player >= _humans) return;
    _match.whack(player, hole);
    setState(() {
      if (_match.isOver) {
        _ticker?.cancel();
        _phase = _MolePhase.over;
      }
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
              setState(() => _phase = _MolePhase.pickBots);
            }),
            for (final n in [2, 3, 4])
              _bigChoice('$n لاعبين', () {
                _humans = n;
                if (n == 4) {
                  _startMatch(4, false);
                } else {
                  setState(() => _phase = _MolePhase.pickBots);
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
                ? 'من غير بوتات هتتدرب لوحدك وتشوف جبت كام خلد'
                : 'البوتات بتكمّل لحد ٤ لاعبين',
            style: _t(14, w: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () => _startMatch(_humans, true)),
          _bigChoice('لا', () => _startMatch(_humans, false)),
        ]),
      );

  Widget _playerPanel(int p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${p >= _humans ? 'بوت' : 'لاعب'} ${p + 1}: ${_match.scores[p]}',
          style: flatCairo(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: FlatColors.ink,
          ).copyWith(fontFamilyFallback: _emojiFallback),
        ),
        const SizedBox(height: 4),
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.maxWidth;
              return GestureDetector(
                key: Key('mole_grid_$p'),
                onTapUp: (d) {
                  final half = side / 2;
                  final col = d.localPosition.dx >= half ? 1 : 0;
                  final row = d.localPosition.dy >= half ? 1 : 0;
                  _whack(p, row * 2 + col);
                },
                child: CustomPaint(
                  painter: _MoleGridPainter(
                    match: _match,
                    player: p,
                    color: _colors[p],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _bigPanel(int p, {bool rotated = false}) {
    return LayoutBuilder(builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight - 28);
      Widget panel = SizedBox(width: side, child: _playerPanel(p));
      if (rotated) panel = Transform.rotate(angle: pi, child: panel);
      return Center(child: panel);
    });
  }

  Widget _buildPlaying() {
    final players = _match.playerCount;
    final rows = (players / 2).ceil();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: LinearProgressIndicator(
            value: 1 - (_match.tickCount / _match.roundTicks).clamp(0.0, 1.0),
            backgroundColor: FlatColors.border,
            color: FlatColors.tilePastels[3],
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        if (players <= 2)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                // the top grid faces the player sitting at the top
                if (players == 2)
                  Expanded(child: _bigPanel(1, rotated: true)),
                Expanded(child: _bigPanel(0)),
              ]),
            ),
          )
        else
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                for (var r = 0; r < rows; r++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var c = 0; c < 2; c++)
                          if (r * 2 + c < players)
                            Expanded(child: _playerPanel(r * 2 + c))
                          else
                            const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOver() {
    final w = _match.winner();
    Widget head;
    if (_practice) {
      head = Text('ضربت ${_match.scores[0]} خلد', style: _t(22));
    } else if (w == null) {
      head = Text('تعادل! الكل ضرب نفس العدد', style: _t(20));
    } else if (w >= _humans) {
      head = Text('البوتات كسبوا 🤖', style: _t(22));
    } else {
      head = VictoryFriends(gameTitle: 'اضرب الخلد', winnerName: 'لاعب ${w + 1}');
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      head,
      const SizedBox(height: 12),
      for (var p = 0; p < _match.playerCount; p++)
        Text('${p >= _humans ? 'بوت' : 'لاعب'} ${p + 1}: ${_match.scores[p]}',
            style: _t(16, color: _colors[p], w: FontWeight.w700)),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => setState(() => _phase = _MolePhase.pickPlayers),
        child: Text('العبوا تاني', style: _t(18, color: Colors.white)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return GameIntroWidget(
        title: 'اضرب الخلد',
        description:
            'لكل لاعب مربع فيه ٤ جحور.. الخلد بيطلع وينزل بسرعة، اضربه في مربعك بس قبل ما يهرب! كل واحد بيطلعله نفس عدد الخلدان، واللي يجيب أكتر قبل ما الوقت يخلص يكسب',
        icon: '🔨',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    return OfflineGameScaffold(
      title: 'اضرب الخلد',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: _phase == _MolePhase.pickPlayers
            ? _buildPicker()
            : _phase == _MolePhase.pickBots
                ? _buildBots()
                : _phase == _MolePhase.playing
                ? _buildPlaying()
                : Center(child: _buildOver()),
      ),
    );
  }
}

class _MoleGridPainter extends CustomPainter {
  _MoleGridPainter({
    required this.match,
    required this.player,
    required this.color,
  });

  final WhackMoleMatch match;
  final int player;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final half = Size(size.width / 2, size.height / 2);
    for (var h = 0; h < WhackMoleMatch.holesPerPlayer; h++) {
      final ox = (h % 2) * half.width + half.width / 2;
      final oy = (h ~/ 2) * half.height + half.height / 2;
      final center = Offset(ox, oy);
      final r = half.width * 0.34;

      // hole
      canvas.drawOval(
        Rect.fromCenter(center: center, width: r * 2.1, height: r * 1.1),
        Paint()..color = const Color(0xFF5A4030),
      );
      if (match.isUp(player, h)) {
        // mole: head + ears + eyes + nose
        final moleBase = center.translate(0, r * 0.32);
        final head = Rect.fromCenter(
            center: moleBase.translate(0, -r * 0.35),
            width: r * 1.5,
            height: r * 1.5);
        canvas.drawOval(head, Paint()..color = const Color(0xFFB08050));
        for (final dx in [-r * 0.55, r * 0.55]) {
          canvas.drawCircle(
            moleBase.translate(dx, -r * 1.05),
            r * 0.28,
            Paint()..color = const Color(0xFFB08050),
          );
          canvas.drawCircle(
            moleBase.translate(dx, -r * 1.05),
            r * 0.14,
            Paint()..color = const Color(0xFF7A5530),
          );
        }
        for (final dx in [-r * 0.3, r * 0.3]) {
          canvas.drawCircle(
            moleBase.translate(dx, -r * 0.5),
            r * 0.11,
            Paint()..color = const Color(0xFF201818),
          );
        }
        canvas.drawCircle(
          moleBase.translate(0, -r * 0.22),
          r * 0.14,
          Paint()..color = const Color(0xFFE87888),
        );
      }
      // grid frame in player color
      canvas.drawRect(
        Rect.fromLTWH(
          (h % 2) * half.width + 4,
          (h ~/ 2) * half.height + 4,
          half.width - 8,
          half.height - 8,
        ),
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_MoleGridPainter oldDelegate) => true;
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import 'snake_arena_logic.dart';

/// حية الشلة: 2-4 snakes on one phone, one turn button per player.
class SnakeArenaGame extends StatefulWidget {
  const SnakeArenaGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<SnakeArenaGame> createState() => _SnakeArenaGameState();
}

enum _SnakePhase { pickPlayers, playing, over }

class _SnakeArenaGameState extends State<SnakeArenaGame> {
  bool _showIntro = true;
  _SnakePhase _phase = _SnakePhase.pickPlayers;
  late SnakeArenaMatch _match;
  Timer? _ticker;

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

  void _startMatch(int players) {
    _ticker?.cancel();
    setState(() {
      _match = SnakeArenaMatch(
        playerCount: players,
        random: widget.randomSeed != null
            ? Random(widget.randomSeed!)
            : null,
      );
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

  Widget _buildPicker() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'كام لاعب؟',
            style: flatCairo(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: FlatColors.ink,
            ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
          ),
          const SizedBox(height: 20),
          for (final n in [2, 3, 4])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: 200,
                child: FilledButton(
                  onPressed: () => _startMatch(n),
                  child: Text(
                    '$n لاعبين',
                    style: flatCairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _scorePill(int i) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _colors[i].withValues(alpha: _match.alive[i] ? 0.3 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _match.alive[i] ? _colors[i] : FlatColors.border),
      ),
      child: Text(
        'لاعب ${i + 1}: ${_match.score[i]}',
        style: flatCairo(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _match.alive[i] ? FlatColors.ink : FlatColors.ink.withValues(alpha: 0.5),
          decoration: _match.alive[i] ? null : TextDecoration.lineThrough,
        ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
      ),
    );
  }

  Widget _turnButton(int i) {
    final active = _phase == _SnakePhase.playing && _match.alive[i];
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
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
            ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (w != null && w >= 0)
          VictoryFriends(winnerName: 'لاعب ${w + 1}')
        else
          Text(
            'تعادل! الكل وقع في بعض 😅',
            style: flatCairo(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: FlatColors.ink,
            ).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _phase = _SnakePhase.pickPlayers),
          child: Text(
            'العبوا تاني 🐍',
            style: flatCairo(fontSize: 18, fontWeight: FontWeight.w800).copyWith(fontFamilyFallback: const ['Noto Color Emoji']),
          ),
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
            '٢-٤ لاعبين على نفس الموبايل. كل واحد ليه زرار واحد بيلفّ بيه حيته. كل التفاح عشان تكبر، ومتخبطش في الحيطة ولا في حد! آخر حية واقفة تكسب 🐍',
        icon: '🐍',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    final players = _phase == _SnakePhase.pickPlayers ? 0 : _match.playerCount;
    return OfflineGameScaffold(
      title: 'حية الشلة',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: _phase == _SnakePhase.pickPlayers
            ? _buildPicker()
            : Column(
                children: [
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
                    child: Row(
                      children: [for (var i = 0; i < players; i++) _turnButton(i)],
                    ),
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

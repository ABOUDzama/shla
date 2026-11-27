import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import '../../services/player_names.dart';
import '../../services/arcade_juice.dart';
import 'tug_of_war_logic.dart';

/// شد الحبل: 1-4 players (+ optional bots), one timing button each,
/// placed on the player's own side (top buttons rotated face-to-face).
class TugOfWarGame extends StatefulWidget {
  const TugOfWarGame({super.key, this.randomSeed});

  /// Fixed RNG seed for deterministic tests; null uses a live random source.
  final int? randomSeed;

  @override
  State<TugOfWarGame> createState() => _TugOfWarGameState();
}

enum _TugPhase { pickPlayers, pickBots, pickMode, playing, over }

class _TugOfWarGameState extends State<TugOfWarGame> {
  static const _emojiFallback = ['Noto Color Emoji'];

  bool _showIntro = true;
  _TugPhase _phase = _TugPhase.pickPlayers;
  late TugMatch _match;
  Timer? _ticker;
  String _banner = '';
  int _humans = 2;
  bool _practice = false;

  @visibleForTesting
  TugMatch get debugMatch => _match;

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

  bool _teamMode = false;
  int _pendingHumans = 2;
  bool _pendingBots = false;

  void _juiceEnd() {
    final w = _match.winner;
    if (w == null) return;
    (w < _humans) ? ArcadeJuice.win() : ArcadeJuice.lose();
  }

  void _startMatch(int humans, bool withBots, {bool teamMode = false}) {
    ArcadeJuice.tap();
    _ticker?.cancel();
    _humans = humans;
    _practice = humans == 1 && !withBots;
    _teamMode = teamMode;
    final seats = _practice ? 1 : (withBots ? 4 : humans);
    final m = TugMatch(
      playerCount: seats,
      random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
      teamMode: teamMode && seats == 4,
    );
    for (var i = humans; i < seats && withBots; i++) {
      m.botSeats.add(i);
    }
    setState(() {
      _match = m;
      _banner = 'دوس لما المؤشر يبقى في النص! 💪';
      _phase = _TugPhase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted || _phase != _TugPhase.playing) return;
      setState(() {
        _match.tick();
        if (_match.isOver) {
          _ticker?.cancel();
          _phase = _TugPhase.over;
        _juiceEnd();
          _juiceEnd();
        }
      });
    });
  }

  void _tap(int i) {
    if (_phase != _TugPhase.playing || i >= _humans) return;
    final grade = _match.tap(i);
    setState(() {
      _banner = switch (grade) {
        'perfect' => '${PlayerNames.name(i)} شدها صح! 💪',
        'ok' => '${PlayerNames.name(i)} شد خفيف',
        _ => '${PlayerNames.name(i)} دوس غلط 😬',
      };
      if (_match.isOver) {
        _ticker?.cancel();
        _phase = _TugPhase.over;
        _juiceEnd();
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
              setState(() => _phase = _TugPhase.pickBots);
            }),
            for (final n in [2, 3, 4])
              _bigChoice('$n لاعبين', () {
                _humans = n;
                if (n == 4) {
                  _pendingHumans = 4;
                  _pendingBots = false;
                  setState(() => _phase = _TugPhase.pickMode);
                } else {
                  setState(() => _phase = _TugPhase.pickBots);
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
                ? 'من غير بوتات هتتدرب لوحدك على توقيت الشدّة'
                : 'البوتات بتكمّل لحد ٤ لاعبين',
            style: _t(14, w: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () {
            _pendingHumans = _humans;
            _pendingBots = true;
            setState(() => _phase = _TugPhase.pickMode);
          }),
          _bigChoice('لا', () => _startMatch(_humans, false)),
        ]),
      );

  Widget _buildMode() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('تقسموا إزاي؟ 👥', style: _t(26)),
          const SizedBox(height: 8),
          Text(
            'الفريق بيشد كله لنفس الناحية.. أول فريق يوصل بالعقدة لطرفه يكسب',
            style: _t(14, w: FontWeight.w600),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 20),
          _bigChoice('فرق 2 ضد 2 👥',
              () => _startMatch(_pendingHumans, _pendingBots, teamMode: true)),
          _bigChoice('كل واحد لوحده 👤',
              () => _startMatch(_pendingHumans, _pendingBots)),
        ]),
      );

  Widget _timingBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const greenW = TugMatch.perfectWindow * 2;
        const okW = TugMatch.okWindow * 2;
        return SizedBox(
          height: 26,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: FlatColors.tileWhite,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: FlatColors.border, width: 2),
                  ),
                ),
              ),
              Positioned(
                left: w * (0.5 - okW / 2),
                width: w * okW,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: FlatColors.tilePastels[4],
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: w * (0.5 - greenW / 2),
                width: w * greenW,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: FlatColors.tilePastels[2],
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: (w * _match.phase - 4).clamp(0.0, w - 8),
                top: 2,
                bottom: 2,
                child: Container(
                  width: 8,
                  decoration: BoxDecoration(
                    color: FlatColors.ink,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArena() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _TugPainter(_match, _colors),
        );
      },
    );
  }

  Widget _pullButton(int i) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          key: Key('tug_pull_$i'),
          style: FilledButton.styleFrom(
            backgroundColor: _colors[i],
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _phase == _TugPhase.playing ? () => _tap(i) : null,
          child: Text(
            '${PlayerNames.name(i)} 💪',
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

  Widget _buildOver() {
    final w = _match.winner;
    Widget head;
    if (_practice) {
      final good = _match.perfects.isNotEmpty ? _match.perfects[0] : 0;
      final bad = _match.misses.isNotEmpty ? _match.misses[0] : 0;
      head = Text('شديت $good شدّة صح وغلطت $bad 💪', style: _t(20));
    } else if (_match.teamMode) {
      final team = _match.winnerTeam!;
      final seats = team == 0 ? [0, 1] : [2, 3];
      final humansInTeam =
          seats.where((x) => !_match.botSeats.contains(x)).toList();
      if (humansInTeam.isEmpty) {
        head = BotsWinLabel(gameTitle: 'شد الحبل', style: _t(22));
      } else {
        head = VictoryFriends(
          // Same title as solo mode so the cup and the leaderboard match it.
          gameTitle: 'شد الحبل',
          winnerName:
              '${humansInTeam.map((x) => PlayerNames.name(x)).join(' و ')}',
          winnerSeats: humansInTeam,
        );
      }
    } else if (w != null && _match.botSeats.contains(w)) {
      head = BotsWinLabel(gameTitle: 'شد الحبل', style: _t(22));
    } else {
      head = VictoryFriends(gameTitle: 'شد الحبل', winnerName: '${PlayerNames.name(w!)}', winnerSeats: [w!]);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        head,
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _phase = _TugPhase.pickPlayers),
          child: Text(
            'العبوا تاني 💪',
            style: flatCairo(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ).copyWith(fontFamilyFallback: _emojiFallback),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return OfflineGameScaffold(
        title: 'شد الحبل',
        backgroundColor: FlatColors.bg,
        body: GameIntroWidget(
        title: 'شد الحبل',
            playersLabel: '١-٤ لاعبين',
            showBotsChip: true,
        description:
            '١-٤ لاعبين على نفس الموبايل، وتقدر تضيف بوتات. المؤشر بيجري يمين وشمال.. دوس لما يبقى في المنطقة الخضرا بالظبط عشان تشد الحبل لناحيتك. اللي يوصل بالعقدة لطرفه يكسب 💪',
        icon: '💪',
        onStart: () => setState(() => _showIntro = false),
      ),
      );
    }
    if (_phase == _TugPhase.pickPlayers ||
        _phase == _TugPhase.pickBots ||
        _phase == _TugPhase.pickMode) {
      return OfflineGameScaffold(
        title: 'شد الحبل',
        backgroundColor: FlatColors.bg,
        body: SafeArea(
          child: _phase == _TugPhase.pickPlayers
              ? _buildPicker()
              : _phase == _TugPhase.pickBots
                  ? _buildBots()
                  : _buildMode(),
        ),
      );
    }
    final humanSeats = [for (var i = 0; i < _humans; i++) i];
    final split = (humanSeats.length / 2).ceil();
    final bottomSeats = humanSeats.take(split).toList();
    final topSeats = humanSeats.skip(split).toList();
    return OfflineGameScaffold(
      title: 'شد الحبل',
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
                          for (var i = topSeats.length - 1; i >= 0; i--)
                            _pullButton(topSeats[i]),
                        ]),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: _timingBar(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: Text(
                      _banner,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: flatCairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: FlatColors.ink,
                      ).copyWith(fontFamilyFallback: _emojiFallback),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _phase == _TugPhase.over
                          ? Center(child: _buildOver())
                          : _buildArena(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                    child: Row(children: [for (final i in bottomSeats) _pullButton(i)]),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TugPainter extends CustomPainter {
  _TugPainter(this.match, this.colors);

  final TugMatch match;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final side = min(size.width, size.height);
    final ox = (size.width - side) / 2;
    final oy = (size.height - side) / 2;
    final center = Offset(ox + side / 2, oy + side / 2);

    final bg = Paint()..color = FlatColors.tileWhite;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(ox, oy, side, side), const Radius.circular(12)),
      bg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(ox, oy, side, side), const Radius.circular(12)),
      Paint()
        ..color = FlatColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // home ring at the center
    canvas.drawCircle(
        center,
        side * 0.06,
        Paint()
          ..color = FlatColors.ink.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = side * 0.008);

    final knot = Offset(center.dx + match.kx * side * 0.42,
        center.dy + match.ky * side * 0.42);

    // anchors: free-for-all uses the four edges; team mode stacks the two
    // teammates on each side edge.
    const ffa = [
      Offset(0.06, 0.5),
      Offset(0.94, 0.5),
      Offset(0.5, 0.08),
      Offset(0.5, 0.92),
    ];
    const teams = [
      Offset(0.06, 0.32),
      Offset(0.06, 0.68),
      Offset(0.94, 0.32),
      Offset(0.94, 0.68),
    ];
    final anchors = match.teamMode ? teams : ffa;
    for (var p = 0; p < match.playerCount; p++) {
      final a = anchors[p];
      final c = Offset(ox + a.dx * side, oy + a.dy * side);
      final col = colors[p];
      final dark = Color.lerp(col, Colors.black, 0.4)!;

      // twisted rope from fist to knot
      final ropePaint = Paint()
        ..color = const Color(0xFFDEB878)
        ..strokeWidth = side * 0.022
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c, knot, ropePaint);
      // rope twist marks
      final dir = (knot - c);
      final len = dir.distance;
      if (len > 0) {
        final unit = dir / len;
        final perp = Offset(-unit.dy, unit.dx);
        final twist = Paint()
          ..color = const Color(0xFFBE965A)
          ..strokeWidth = side * 0.006
          ..strokeCap = StrokeCap.round;
        for (var t = side * 0.06; t < len - side * 0.05; t += side * 0.045) {
          final m = c + unit * t;
          canvas.drawLine(
              m - perp * side * 0.011 + unit * side * 0.008,
              m + perp * side * 0.011 - unit * side * 0.008,
              twist);
        }
      }

      // arm: capsule sleeve in player color pointing at the knot
      final inward = (knot - c);
      final u = inward.distance > 0 ? inward / inward.distance : Offset.zero;
      final elbow = c - u * side * 0.02;
      final fist = c + u * side * 0.05;
      canvas.drawLine(
          elbow,
          fist,
          Paint()
            ..color = col
            ..strokeWidth = side * 0.05
            ..strokeCap = StrokeCap.round);
      // fist on the rope
      canvas.drawCircle(fist, side * 0.038, Paint()..color = col);
      canvas.drawCircle(
          fist,
          side * 0.038,
          Paint()
            ..color = dark
            ..style = PaintingStyle.stroke
            ..strokeWidth = side * 0.007);
      // knuckle lines
      for (var k = -1; k <= 1; k++) {
        final kp = fist + Offset(-u.dy, u.dx) * (k * side * 0.016);
        canvas.drawCircle(kp + u * side * 0.018, side * 0.008,
            Paint()..color = dark.withValues(alpha: 0.7));
      }
    }

    // knot
    canvas.drawCircle(knot, side * 0.038, Paint()..color = FlatColors.tilePastels[4]);
    canvas.drawCircle(
        knot,
        side * 0.038,
        Paint()
          ..color = FlatColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = side * 0.008);
    canvas.drawCircle(
        knot, side * 0.012, Paint()..color = const Color(0xFFFFF3C0));
  }

  @override
  bool shouldRepaint(_TugPainter oldDelegate) => true;
}

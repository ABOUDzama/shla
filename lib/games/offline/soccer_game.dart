import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/flat_theme.dart';
import '../../widgets/game_intro_widget.dart';
import '../../widgets/offline_game_scaffold.dart';
import '../../widgets/victory_friends.dart';
import 'soccer_logic.dart';

/// كورة الشلة: top-down 2v2 soccer. Players auto-run; each steers with two
/// corner pads (left / right). No kick button: run into the ball.
/// 1-4 humans, optional bots to fill 2v2. One human with no bots is an
/// honest practice mode (a frozen opponent, no winner recorded).
class SoccerGame extends StatefulWidget {
  const SoccerGame({super.key, this.randomSeed});
  final int? randomSeed;

  @override
  State<SoccerGame> createState() => _SoccerGameState();
}

enum _SoccerPhase { pickPlayers, pickBots, playing, over }

class _SoccerGameState extends State<SoccerGame> {
  static const _emojiFallback = ['Noto Color Emoji'];
  static const _teamColors = [Color(0xFFFF8A5C), Color(0xFF4D8DFF)];

  bool _showIntro = true;
  _SoccerPhase _phase = _SoccerPhase.pickPlayers;
  late SoccerMatch _match;
  Timer? _ticker;
  int _humans = 2;
  bool _practice = false;

  /// Logic player index for each human seat (seat i is "لاعب i+1").
  List<int> _seatPlayer = [];
  final Map<int, int> _turn = {};

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Seats fill: team0 slot0, team1 slot0, team0 slot1, team1 slot1.
  void _startMatch(int humans, bool withBots) {
    _ticker?.cancel();
    _humans = humans;
    _practice = humans == 1 && !withBots;
    late List<int> sizes;
    if (withBots || humans == 4) {
      sizes = [2, 2];
    } else if (humans == 3) {
      sizes = [2, 1];
    } else {
      sizes = [1, 1];
    }
    final m = SoccerMatch(
      teamSizes: sizes,
      random: widget.randomSeed != null ? Random(widget.randomSeed!) : null,
    );
    // logic index of (team, slot)
    int idx(int team, int slot) => team == 0 ? slot : sizes[0] + slot;
    final order = [
      [0, 0],
      [1, 0],
      [0, 1],
      [1, 1]
    ];
    _seatPlayer = [
      for (var i = 0; i < humans; i++) idx(order[i][0], order[i][1])
    ];
    for (var i = 0; i < m.players.length; i++) {
      if (!_seatPlayer.contains(i)) {
        if (_practice) {
          m.frozenIndexes.add(i);
        } else {
          m.botIndexes.add(i);
        }
      }
    }
    _turn.clear();
    setState(() {
      _match = m;
      _phase = _SoccerPhase.playing;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted || _phase != _SoccerPhase.playing) return;
      setState(() {
        _match.step(0.033, _turn);
        if (_match.over) {
          _ticker?.cancel();
          _phase = _SoccerPhase.over;
        }
      });
    });
  }

  void _setTurn(int seat, int dir) {
    if (_phase != _SoccerPhase.playing) return;
    _turn[_seatPlayer[seat]] = dir;
  }

  @visibleForTesting
  SoccerMatch get debugMatch => _match;

  @visibleForTesting
  List<int> get debugSeatPlayers => _seatPlayer;

  @visibleForTesting
  void debugForceScore(int team, int goals) {
    setState(() {
      _match.scores[team] = goals;
      if (_match.over) {
        _ticker?.cancel();
        _phase = _SoccerPhase.over;
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('كام لاعب؟', style: _t(26)),
          const SizedBox(height: 20),
          _bigChoice('لاعب واحد', () {
            _humans = 1;
            setState(() => _phase = _SoccerPhase.pickBots);
          }),
          for (final n in [2, 3, 4])
            _bigChoice('$n لاعبين', () {
              _humans = n;
              if (n == 4) {
                _startMatch(4, false);
              } else {
                setState(() => _phase = _SoccerPhase.pickBots);
              }
            }),
        ]),
      );

  Widget _buildBotsPrompt() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('نضيف بوتات؟', style: _t(26)),
          const SizedBox(height: 8),
          Text(
            _humans == 1
                ? 'من غير بوتات هتتدرب لوحدك على الكورة'
                : 'البوتات بتكمّل الفريقين ٢ ضد ٢',
            style: _t(14, w: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          _bigChoice('اه 🤖', () => _startMatch(_humans, true)),
          _bigChoice('لا', () => _startMatch(_humans, false)),
        ]),
      );

  // Pads: seat -> corner. team0 bottom (slot0 left, slot1 right),
  // team1 top (slot0 right, slot1 left).
  Alignment _corner(int seat) {
    const c = [
      Alignment.bottomLeft,
      Alignment.topRight,
      Alignment.bottomRight,
      Alignment.topLeft,
    ];
    return c[seat];
  }

  Widget _pad(int seat, int dir) {
    final team = const [0, 1, 0, 1][seat];
    final color = _teamColors[team];
    return Listener(
      key: ValueKey('pad_${seat}_${dir < 0 ? 'l' : 'r'}'),
      onPointerDown: (_) => _setTurn(seat, dir),
      onPointerUp: (_) => _setTurn(seat, 0),
      onPointerCancel: (_) => _setTurn(seat, 0),
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.85),
          border: Border.all(color: FlatColors.ink, width: 2.5),
        ),
        child: Icon(dir < 0 ? Icons.rotate_left_rounded : Icons.rotate_right_rounded,
            color: Colors.white, size: 34),
      ),
    );
  }

  Widget _pads() {
    return Stack(children: [
      for (var s = 0; s < _humans; s++)
        Align(
          alignment: _corner(s),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _pad(s, -1),
              const SizedBox(width: 6),
              _pad(s, 1),
            ]),
          ),
        ),
    ]);
  }

  String _teamName(int team) {
    final seats = <int>[];
    for (var s = 0; s < _humans; s++) {
      final p = _match.players[_seatPlayer[s]];
      if (p.team == team) seats.add(s + 1);
    }
    if (seats.isEmpty) return 'البوتات';
    return seats.map((s) => 'لاعب $s').join(' و ');
  }

  Widget _buildOver() {
    final w = _match.winner;
    Widget head;
    if (_practice) {
      head = Text('انتهت جولة التدريب 👏\nأهدافك: ${_match.scores[0]}', textAlign: TextAlign.center, style: _t(20));
    } else if (w == null) {
      head = Text('تعادل ${_match.scores[0]} - ${_match.scores[1]} 🤝', style: _t(22));
    } else {
      final name = _teamName(w);
      head = name == 'البوتات'
          ? Text('البوتات كسبوا ${_match.scores[w]} - ${_match.scores[1 - w]} 🤖', style: _t(20))
          : VictoryFriends(gameTitle: 'كورة الشلة', winnerName: name);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      head,
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => setState(() => _phase = _SoccerPhase.pickPlayers),
        child: Text('العبوا تاني ⚽', style: _t(18, color: Colors.white)),
      ),
    ]);
  }

  Widget _scoreHeader() {
    final t = _match.timeLeft.ceil();
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('${_match.scores[0]}', style: _t(26, color: const Color(0xFFD9541E))),
      const SizedBox(width: 14),
      Text('${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}', style: _t(16, w: FontWeight.w700)),
      const SizedBox(width: 14),
      Text('${_match.scores[1]}', style: _t(26, color: const Color(0xFF1F5FD6))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return GameIntroWidget(
        title: 'كورة الشلة',
        description:
            'كورة ٢ ضد ٢ بموبايل واحد. لاعبك بيجري لوحده: دوس على سهم يمين أو شمال في ركنك عشان تلفّ، واخبط في الكورة عشان تضربها ناحية الجون. من غير زرار ضرب. أول فريق يسجل ٣ أهداف أو أكتر أهداف بعد ٩٠ ثانية يكسب ⚽',
        icon: '⚽',
        onStart: () => setState(() => _showIntro = false),
      );
    }
    return OfflineGameScaffold(
      title: 'كورة الشلة',
      backgroundColor: FlatColors.bg,
      body: SafeArea(
        child: switch (_phase) {
          _SoccerPhase.pickPlayers => _buildPicker(),
          _SoccerPhase.pickBots => _buildBotsPrompt(),
          _SoccerPhase.over => Center(child: _buildOver()),
          _SoccerPhase.playing => Column(children: [
              _scoreHeader(),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  final h = c.maxHeight - 8;
                  final w = min(c.maxWidth - 8, h / SoccerMatch.fieldH);
                  final ph = w * SoccerMatch.fieldH;
                  return Center(
                    child: SizedBox(
                      width: w,
                      height: ph,
                      child: Stack(children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _PitchPainter(_match)),
                        ),
                        Positioned.fill(child: _pads()),
                        if (_match.goalPause > 0)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: FlatColors.ink, width: 2.5),
                              ),
                              child: Text('جووول! ⚽', style: _t(26)),
                            ),
                          ),
                      ]),
                    ),
                  );
                }),
              ),
            ]),
        },
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  _PitchPainter(this.m);
  final SoccerMatch m;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final k = w; // logic units -> px (width = 1)
    final line = Paint()
      ..color = FlatColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18));
    canvas.drawRRect(r, Paint()..color = FlatColors.tileWhite);
    canvas.drawRRect(r, line);
    canvas.drawLine(Offset(0, size.height / 2), Offset(w, size.height / 2), line);
    canvas.drawCircle(Offset(w / 2, size.height / 2), 0.15 * k, line);
    // goals (ink outlined mouths)
    final gw = SoccerMatch.goalHalfWidth * 2 * k;
    final goalPaint = Paint()
      ..color = FlatColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawLine(Offset(w / 2 - gw / 2, 0), Offset(w / 2 + gw / 2, 0), goalPaint);
    canvas.drawLine(Offset(w / 2 - gw / 2, size.height), Offset(w / 2 + gw / 2, size.height), goalPaint);
    // keepers
    for (final kp in SoccerMatch.keepers) {
      canvas.drawCircle(Offset(kp.x * k, kp.y * k), SoccerMatch.keeperR * k, Paint()..color = const Color(0xFF8A8FA3));
      canvas.drawCircle(Offset(kp.x * k, kp.y * k), SoccerMatch.keeperR * k,
          Paint()..color = FlatColors.ink..style = PaintingStyle.stroke..strokeWidth = 2.5);
    }
    // players
    const colors = [Color(0xFFFF8A5C), Color(0xFF4D8DFF)];
    for (final p in m.players) {
      final c = Offset(p.x * k, p.y * k);
      canvas.drawCircle(c, SoccerMatch.playerR * k, Paint()..color = colors[p.team]);
      canvas.drawCircle(c, SoccerMatch.playerR * k,
          Paint()..color = FlatColors.ink..style = PaintingStyle.stroke..strokeWidth = 2.5);
      final nose = c + Offset(cos(p.heading), sin(p.heading)) * (SoccerMatch.playerR * k * 0.95);
      canvas.drawCircle(nose, 4, Paint()..color = FlatColors.ink);
    }
    // ball
    final b = Offset(m.ballX * k, m.ballY * k);
    canvas.drawCircle(b, SoccerMatch.ballR * k, Paint()..color = Colors.white);
    canvas.drawCircle(b, SoccerMatch.ballR * k,
        Paint()..color = FlatColors.ink..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) => true;
}
